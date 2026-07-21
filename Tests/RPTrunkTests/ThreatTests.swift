@testable import RPTrunk
import XCTest

final class ThreatTests: XCTestCase {
    var rpSpace: TestRPSpace!

    override func setUp() {
        rpSpace = TestRPSpace()
        TestRPSpace.threatRule = nil
    }

    override func tearDown() {
        TestRPSpace.threatRule = nil
    }

    // MARK: - Target selection

    func testGetTargetIsDeterministicWithoutThreat() {
        var entity = RPEntity<TestRPSpace>(["hp": 10])
        entity.targets = ["c", "a", "b"]
        XCTAssertEqual(entity.getTarget(), "a", "no threat: lowest id wins, always")
    }

    func testGetTargetPrefersHighestThreat() {
        var entity = RPEntity<TestRPSpace>(["hp": 10])
        entity.targets = ["a", "b", "c"]
        entity.addThreat(toward: "b", amount: 10)
        entity.addThreat(toward: "c", amount: 5)
        XCTAssertEqual(entity.getTarget(), "b")
    }

    func testGetTargetBreaksThreatTiesById() {
        var entity = RPEntity<TestRPSpace>(["hp": 10])
        entity.targets = ["b", "c"]
        entity.addThreat(toward: "b", amount: 10)
        entity.addThreat(toward: "c", amount: 10)
        XCTAssertEqual(entity.getTarget(), "b")
    }

    func testGetTargetIgnoresThreatOutsidePerception() {
        var entity = RPEntity<TestRPSpace>(["hp": 10])
        entity.targets = ["a"]
        entity.addThreat(toward: "z", amount: 100) // no longer a valid target
        XCTAssertEqual(entity.getTarget(), "a")
    }

    func testFriendlyTargetingIgnoresThreat() {
        var healer = RPEntity<TestRPSpace>(["hp": 10])
        healer.id = "healer"
        var allyA = RPEntity<TestRPSpace>(["hp": 10])
        allyA.id = "ally-a"
        var allyB = RPEntity<TestRPSpace>(["hp": 10])
        allyB.id = "ally-b"

        var team = RPTeam<TestRPSpace>()
        team.add(&healer)
        team.add(&allyA)
        team.add(&allyB)

        healer.targets = ["ally-a", "ally-b"]
        // threat toward an ally (however it got there) must not steer heals
        healer.addThreat(toward: "ally-b", amount: 100)

        var space = TestRPSpace()
        space.addEntity(healer)
        space.addEntity(allyA)
        space.addEntity(allyB)
        space.setTeams([team])

        let targeting = RPTargeting<TestRPSpace>(.singleFriendly, .always)
        XCTAssertEqual(targeting.getValidTargets(for: "healer", in: space), ["ally-a"])
    }

    // MARK: - Table mechanics

    func testThreatClampsAtZeroAndRemovesEntries() {
        var entity = RPEntity<TestRPSpace>(["hp": 10])
        entity.addThreat(toward: "a", amount: 10)
        entity.addThreat(toward: "a", amount: -25)
        XCTAssertFalse(entity.holdsThreat(toward: "a"))
        XCTAssertTrue(entity.threat.isEmpty)
    }

    func testThreatListIsOrdered() {
        var entity = RPEntity<TestRPSpace>(["hp": 10])
        entity.addThreat(toward: "c", amount: 5)
        entity.addThreat(toward: "a", amount: 10)
        entity.addThreat(toward: "b", amount: 10)
        XCTAssertEqual(entity.threatList.map(\.entityId), ["a", "b", "c"])
        XCTAssertEqual(entity.threatList.map(\.threat), [10, 10, 5])
    }

    func testThreatDecayRemovesEntriesOverTime() {
        var entity = RPEntity<TestRPSpace>(["hp": 10])
        entity.threatDecayPerTick = 2
        entity.addThreat(toward: "a", amount: 5)

        entity.tick(RPMoment(delta: 1)) // -2 -> 3
        XCTAssertEqual(entity.threat["a"], 3)

        entity.tick(RPMoment(delta: 2)) // -4 -> clamped out
        XCTAssertFalse(entity.holdsThreat(toward: "a"))
    }

    func testDecayDisabledByDefault() {
        var entity = RPEntity<TestRPSpace>(["hp": 10])
        entity.addThreat(toward: "a", amount: 5)
        entity.tick(RPMoment(delta: 100))
        XCTAssertEqual(entity.threat["a"], 5)
    }

    // MARK: - Space-level queries and cleanup

    func testSpaceThreatQueriesAndCleanup() {
        var attacker = RPEntity<TestRPSpace>(["hp": 10])
        attacker.id = "attacker"
        var bystander = RPEntity<TestRPSpace>(["hp": 10])
        bystander.id = "bystander"
        var victim = RPEntity<TestRPSpace>(["hp": 10])
        victim.id = "victim"

        rpSpace.addEntity(attacker)
        rpSpace.addEntity(bystander)
        rpSpace.addEntity(victim)

        rpSpace.applyThreatChanges([
            .init(holder: "attacker", toward: "victim", delta: 12),
        ])

        XCTAssertTrue(rpSpace.isThreatened("victim"))
        XCTAssertEqual(rpSpace.entitiesThreatening("victim"), ["attacker"])
        XCTAssertFalse(rpSpace.isThreatened("bystander"))

        // victim leaves play: every table drops it
        rpSpace.clearAllThreat(toward: "victim")
        XCTAssertFalse(rpSpace.isThreatened("victim"))
        XCTAssertEqual(rpSpace.entityById("attacker")?.threat.isEmpty, true)
    }

    // MARK: - RPEvent pipeline integration

    func makeCombatSpace() -> (TestRPSpace, attacker: RPEntityId, target: RPEntityId) {
        var attacker = RPEntity<TestRPSpace>(["hp": 30, "damage": 4])
        attacker.id = "attacker"
        var target = RPEntity<TestRPSpace>(["hp": 30])
        target.id = "target"
        attacker.targets = [target.id]

        var space = TestRPSpace()
        var attackerTeam = RPTeam<TestRPSpace>()
        attackerTeam.add(&attacker)
        var targetTeam = RPTeam<TestRPSpace>()
        targetTeam.add(&target)
        attackerTeam.enemies = [targetTeam.id]
        targetTeam.enemies = [attackerTeam.id]
        space.addEntity(attacker)
        space.addEntity(target)
        space.setTeams([attackerTeam, targetTeam])
        return (space, attacker.id, target.id)
    }

    func makeAttack() -> RPAbility<TestRPSpace> {
        var stats = TestStats()
        stats.damage = 4
        return RPAbility(code: "Attack", components: [Component(stats: stats)])
    }

    func testEventsProduceNoThreatByDefault() {
        var (space, attackerId, targetId) = makeCombatSpace()
        let event = RPEvent(initiator: attackerId, ability: makeAttack(), rpSpace: space)

        _ = space.performEvents([event])

        XCTAssertEqual(space.entityById(attackerId)?.threat.isEmpty, true)
        XCTAssertEqual(space.entityById(targetId)?.threat.isEmpty, true)
    }

    func testEventsProduceThreatViaConformanceRule() {
        var (space, attackerId, targetId) = makeCombatSpace()

        // being targeted by a hostile event builds threat toward the attacker
        // (TestRPSpace's resolveConflict is a stub, so the rule keys off the
        // event rather than the resolved stat changes)
        TestRPSpace.threatRule = { eventResult in
            guard let initiator = eventResult.event.initiator else { return [] }
            return eventResult.event.targets.map { targetId in
                ThreatChange(holder: targetId, toward: initiator, delta: 4)
            }
        }

        let event = RPEvent(initiator: attackerId, ability: makeAttack(), rpSpace: space)
        _ = space.performEvents([event])

        let victim = space.entityById(targetId)
        XCTAssertEqual(victim?.threat[attackerId], 4)
        XCTAssertTrue(space.isThreatened(attackerId))
    }
}

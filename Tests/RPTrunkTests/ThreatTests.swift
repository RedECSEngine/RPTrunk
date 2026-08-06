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
        var body = RPBody<TestRPSpace>(["hp": 10])
        body.targets = ["c", "a", "b"]
        XCTAssertEqual(body.getTarget(), "a", "no threat: lowest id wins, always")
    }

    func testGetTargetPrefersHighestThreat() {
        var body = RPBody<TestRPSpace>(["hp": 10])
        body.targets = ["a", "b", "c"]
        body.addThreat(toward: "b", amount: 10)
        body.addThreat(toward: "c", amount: 5)
        XCTAssertEqual(body.getTarget(), "b")
    }

    func testGetTargetBreaksThreatTiesById() {
        var body = RPBody<TestRPSpace>(["hp": 10])
        body.targets = ["b", "c"]
        body.addThreat(toward: "b", amount: 10)
        body.addThreat(toward: "c", amount: 10)
        XCTAssertEqual(body.getTarget(), "b")
    }

    func testGetTargetIgnoresThreatOutsidePerception() {
        var body = RPBody<TestRPSpace>(["hp": 10])
        body.targets = ["a"]
        body.addThreat(toward: "z", amount: 100) // no longer a valid target
        XCTAssertEqual(body.getTarget(), "a")
    }

    func testFriendlyTargetingIgnoresThreat() {
        var healer = RPBody<TestRPSpace>(["hp": 10])
        healer.id = "healer"
        var allyA = RPBody<TestRPSpace>(["hp": 10])
        allyA.id = "ally-a"
        var allyB = RPBody<TestRPSpace>(["hp": 10])
        allyB.id = "ally-b"

        var team = RPTeam<TestRPSpace>()
        team.add(&healer)
        team.add(&allyA)
        team.add(&allyB)

        healer.targets = ["ally-a", "ally-b"]
        // threat toward an ally (however it got there) must not steer heals
        healer.addThreat(toward: "ally-b", amount: 100)

        var space = TestRPSpace()
        space.addBody(healer)
        space.addBody(allyA)
        space.addBody(allyB)
        space.setTeams([team])

        let targeting = RPTargeting<TestRPSpace>(.friendly, sort: .anyone)
        XCTAssertEqual(targeting.getValidTargets(for: "healer", in: space), ["ally-a"])
    }

    // MARK: - Table mechanics

    func testThreatClampsAtZeroAndRemovesEntries() {
        var body = RPBody<TestRPSpace>(["hp": 10])
        body.addThreat(toward: "a", amount: 10)
        body.addThreat(toward: "a", amount: -25)
        XCTAssertFalse(body.holdsThreat(toward: "a"))
        XCTAssertTrue(body.threat.isEmpty)
    }

    func testThreatListIsOrdered() {
        var body = RPBody<TestRPSpace>(["hp": 10])
        body.addThreat(toward: "c", amount: 5)
        body.addThreat(toward: "a", amount: 10)
        body.addThreat(toward: "b", amount: 10)
        XCTAssertEqual(body.threatList.map(\.bodyId), ["a", "b", "c"])
        XCTAssertEqual(body.threatList.map(\.threat), [10, 10, 5])
    }

    func testThreatDecayRemovesEntriesOverTime() {
        var body = RPBody<TestRPSpace>(["hp": 10])
        body.threatDecayPerTick = 2
        body.addThreat(toward: "a", amount: 5)

        body.tick(RPMoment(delta: 1)) // -2 -> 3
        XCTAssertEqual(body.threat["a"], 3)

        body.tick(RPMoment(delta: 2)) // -4 -> clamped out
        XCTAssertFalse(body.holdsThreat(toward: "a"))
    }

    func testDecayDisabledByDefault() {
        var body = RPBody<TestRPSpace>(["hp": 10])
        body.addThreat(toward: "a", amount: 5)
        body.tick(RPMoment(delta: 100))
        XCTAssertEqual(body.threat["a"], 5)
    }

    // MARK: - Space-level queries and cleanup

    func testSpaceThreatQueriesAndCleanup() {
        var attacker = RPBody<TestRPSpace>(["hp": 10])
        attacker.id = "attacker"
        var bystander = RPBody<TestRPSpace>(["hp": 10])
        bystander.id = "bystander"
        var victim = RPBody<TestRPSpace>(["hp": 10])
        victim.id = "victim"

        rpSpace.addBody(attacker)
        rpSpace.addBody(bystander)
        rpSpace.addBody(victim)

        rpSpace.applyThreatChanges([
            .init(holder: "attacker", toward: "victim", delta: 12),
        ])

        XCTAssertTrue(rpSpace.isThreatened("victim"))
        XCTAssertEqual(rpSpace.bodiesThreatening("victim"), ["attacker"])
        XCTAssertFalse(rpSpace.isThreatened("bystander"))

        // victim leaves play: every table drops it
        rpSpace.clearAllThreat(toward: "victim")
        XCTAssertFalse(rpSpace.isThreatened("victim"))
        XCTAssertEqual(rpSpace.bodyById("attacker")?.threat.isEmpty, true)
    }

    // MARK: - RPEvent pipeline integration

    func makeCombatSpace() -> (TestRPSpace, attacker: RPBodyId, target: RPBodyId) {
        var attacker = RPBody<TestRPSpace>(["hp": 30, "damage": 4])
        attacker.id = "attacker"
        var target = RPBody<TestRPSpace>(["hp": 30])
        target.id = "target"
        attacker.targets = [target.id]

        var space = TestRPSpace()
        var attackerTeam = RPTeam<TestRPSpace>()
        attackerTeam.add(&attacker)
        var targetTeam = RPTeam<TestRPSpace>()
        targetTeam.add(&target)
        attackerTeam.enemies = [targetTeam.id]
        targetTeam.enemies = [attackerTeam.id]
        space.addBody(attacker)
        space.addBody(target)
        space.setTeams([attackerTeam, targetTeam])
        return (space, attacker.id, target.id)
    }

    func makeAttack() -> RPAbility<TestRPSpace> {
        var stats = TestStats()
        stats.damage = 4
        return RPAbility(code: "Attack", fragments: [RPFragment(stats: stats)])
    }

    func testEventsProduceNoThreatByDefault() {
        var (space, attackerId, targetId) = makeCombatSpace()
        let event = RPEvent(initiator: attackerId, ability: makeAttack(), rpSpace: space)

        _ = space.performEvents([event])

        XCTAssertEqual(space.bodyById(attackerId)?.threat.isEmpty, true)
        XCTAssertEqual(space.bodyById(targetId)?.threat.isEmpty, true)
    }

    func testEventsProduceThreatViaConformanceRule() {
        var (space, attackerId, targetId) = makeCombatSpace()

        // being targeted by a hostile event builds threat toward the attacker
        // (TestRPSpace's resolveConflict is a stub, so the rule keys off the
        // event rather than the resolved stat changes)
        TestRPSpace.threatRule = { eventResult in
            guard let initiator = eventResult.event.initiator else { return [] }
            return eventResult.event.targets.map { targetId in
                RPThreatChange(holder: targetId, toward: initiator, delta: 4)
            }
        }

        let event = RPEvent(initiator: attackerId, ability: makeAttack(), rpSpace: space)
        _ = space.performEvents([event])

        let victim = space.bodyById(targetId)
        XCTAssertEqual(victim?.threat[attackerId], 4)
        XCTAssertTrue(space.isThreatened(attackerId))
    }
}

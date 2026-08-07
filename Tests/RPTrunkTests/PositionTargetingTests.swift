@testable import RPTrunk
import XCTest

final class PositionTargetingTests: XCTestCase {
    var rpSpace: TestRPSpace!

    override func setUp() {
        TestRPSpace.resetTestHooks()
        rpSpace = TestRPSpace()

        var hero = RPBody<TestRPSpace>(["hp": 30])
        hero.id = "hero"
        var foeNear = RPBody<TestRPSpace>(["hp": 30])
        foeNear.id = "foe-near"
        var foeMid = RPBody<TestRPSpace>(["hp": 25])
        foeMid.id = "foe-mid"
        var foeFar = RPBody<TestRPSpace>(["hp": 20])
        foeFar.id = "foe-far"

        var heroTeam = RPTeam<TestRPSpace>()
        heroTeam.add(&hero)
        var foeTeam = RPTeam<TestRPSpace>()
        foeTeam.add(&foeNear)
        foeTeam.add(&foeMid)
        foeTeam.add(&foeFar)
        heroTeam.enemies = [foeTeam.id]
        foeTeam.enemies = [heroTeam.id]

        rpSpace.addBody(hero)
        rpSpace.addBody(foeNear)
        rpSpace.addBody(foeMid)
        rpSpace.addBody(foeFar)
        rpSpace.setTeams([heroTeam, foeTeam])

        rpSpace.positions["foe-mid"] = .init(x: 0.5, y: 0)
        rpSpace.positions["foe-far"] = .init(x: 10, y: 0)
    }

    override func tearDown() {
        TestRPSpace.resetTestHooks()
    }

    func testPerceptionIsBoundedByTargetingRange() {
        let targeting = RPTargeting<TestRPSpace>(.enemy)
        XCTAssertEqual(targeting.getValidTargets(for: "hero", in: rpSpace), ["foe-near", "foe-mid"])
    }

    func testRaisingTargetingRangeExtendsPerception() {
        rpSpace.bodies["hero"]?.targetingRange = 15
        let targeting = RPTargeting<TestRPSpace>(.enemy)
        XCTAssertEqual(
            targeting.getValidTargets(for: "hero", in: rpSpace),
            ["foe-near", "foe-mid", "foe-far"]
        )
    }

    func testAThreatHolderBeyondRangeStaysPerceived() {
        rpSpace.bodies["foe-far"]?.addThreat(toward: "hero", amount: 5)
        let targeting = RPTargeting<TestRPSpace>(.enemy)
        XCTAssertEqual(
            targeting.getValidTargets(for: "hero", in: rpSpace),
            ["foe-near", "foe-mid", "foe-far"],
            "a body engaged with the observer never drops out of perception"
        )
    }

    func testShouldCheckExcludesACandidateEarly() {
        TestRPSpace.shouldCheckRule = { id, _ in id != "foe-near" }
        let targeting = RPTargeting<TestRPSpace>(.enemy)
        XCTAssertEqual(targeting.getValidTargets(for: "hero", in: rpSpace), ["foe-mid"])
    }

    func testWillTargetWalksTheRankedOrderAndStopsAtTheFirstAcceptedCandidate() throws {
        rpSpace.bodies["hero"]?.targetingRange = 15
        var checked: [RPBodyId] = []
        TestRPSpace.willTargetRule = { id, _ in
            checked.append(id)
            return id != "foe-far"
        }

        let targeting = try RPTargeting<TestRPSpace>.fromString("enemy sort: hp.lowest")
        XCTAssertEqual(targeting.getValidTargets(for: "hero", in: rpSpace), ["foe-mid"])
        XCTAssertEqual(checked, ["foe-far", "foe-mid"])
    }

    func testSelfPoolIgnoresValidityHooks() {
        TestRPSpace.shouldCheckRule = { _, _ in false }
        TestRPSpace.willTargetRule = { _, _ in false }
        let targeting = RPTargeting<TestRPSpace>(.oneself)
        XCTAssertEqual(targeting.getValidTargets(for: "hero", in: rpSpace), ["hero"])
    }

    func testInitiatorPoolIgnoresValidityHooks() {
        TestRPSpace.shouldCheckRule = { _, _ in false }
        TestRPSpace.willTargetRule = { _, _ in false }

        let attack = RPEvent<TestRPSpace>(
            initiator: "foe-near",
            ability: RPAbility(code: "Attack"),
            targets: ["hero"],
            rpSpace: rpSpace
        )
        let targeting = RPTargeting<TestRPSpace>(.initiator)
        XCTAssertEqual(
            targeting.getValidTargets(for: "hero", in: rpSpace, reactingTo: attack),
            ["foe-near"]
        )
    }

    func testRangesLoadFromJSONAndTheDefaultBodyCascades() throws {
        let cache = RPCache<TestRPSpace>()
        try cache.load(.init(
            abilities: [
                "ability.attack": .init(cooldown: nil, executionRange: 16),
                "ability.fire": .init(cooldown: nil),
            ],
            bodies: [
                "scout": .init(targetingRange: 120),
                "grunt": .init(),
            ],
            defaultBody: .init(targetingRange: 80)
        ))

        XCTAssertEqual(cache.abilities["ability.attack"]?.executionRange, 16)
        XCTAssertNil(cache.abilities["ability.fire"]?.executionRange)
        XCTAssertEqual(cache.bodies["scout"]?.targetingRange, 120)
        XCTAssertEqual(
            cache.bodies["grunt"]?.targetingRange,
            80,
            "a body that declares no range inherits the default body's"
        )
    }
}

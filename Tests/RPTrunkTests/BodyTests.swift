@testable import RPTrunk
import XCTest



final class BodyTests: XCTestCase {
    static var allTests = [
        ("test_should_be_able_to_have_any_stats_value_within_the_baseStats_range", test_should_be_able_to_have_any_stats_value_within_the_baseStats_range),
    ]

    var body: RPBody<TestRPSpace>!
    var enemy: RPBody<TestRPSpace>!
    var rpSpace: TestRPSpace!

    override func setUp() {

        body = RPBody(["hp": 30])
        enemy = RPBody(["hp": 30])
        rpSpace = TestRPSpace()

        var bodyTeam = RPTeam<TestRPSpace>()
        bodyTeam.add(&body)
        var enemyTeam = RPTeam<TestRPSpace>()
        enemyTeam.add(&enemy)
        
        rpSpace.addBody(body)
        rpSpace.addBody(enemy)
        rpSpace.setTeams([bodyTeam, enemyTeam])
    }

    func test_should_be_able_to_have_any_stats_value_within_the_baseStats_range() {
        body.setCurrentStats(.init(dict: [\.hp: 15, \.damage: 0]))
        XCTAssertEqual(body.hp, 15)
        XCTAssertEqual(body.damage, 0)
    }

    func test_should_not_be_able_to_exceed_base_stats() {
        body.setCurrentStats(.init(dict: [\.hp: 45, \.damage: 10]))
        XCTAssertEqual(body.hp, 30)
        XCTAssertEqual(body.damage, 0)
    }
    
    func test_body_stats_are_sum_of_components() {
        body.equipment.equip(TestEquipment.sword)
        body.equipment.equip(TestEquipment.helmet)

        XCTAssertEqual(body.equipment.wornItems.count, 2)
        XCTAssertEqual(body.cumulativeWornStats().damage, 15)

        body.setCurrentStats(.init(dict: [\.damage: 100]))
        XCTAssertEqual(body.damage, 15)
    }

    func test_passive_abilities_should_trigger_on_event_occurrences() {
        let ability = RPAbility<TestRPSpace>(code: "Test")
        rpSpace.bodies[body.id]?.addPassiveAbility(ability, conditional: .always)

        let enemyAbility = RPAbility<TestRPSpace>(code: "enemyAbility")
        let fakeEvent = RPEvent(initiator: enemy.id, ability: enemyAbility, rpSpace: rpSpace)

        _ = fakeEvent.execute(in: &rpSpace)
        let reactionEvents = rpSpace.bodies[body.id]?.getPendingPassiveEvents(in: rpSpace)
        XCTAssertEqual(reactionEvents?.count, 1)
        XCTAssertEqual(reactionEvents?.first?.ability, ability)
    }

    func test_global_cooldown_gates_actions_even_when_the_ability_is_ready() {
        let ability = RPAbility<TestRPSpace>(
            code: "Strike",
            fragments: [RPFragment(targetType: RPTargeting(.oneself, .always))]
        )
        rpSpace.bodies[body.id]?.addExecutableAbility(ability, conditional: .always)

        let firstEvents = rpSpace.bodies[body.id]!.getPendingExecutableEvents(in: rpSpace)
        XCTAssertEqual(firstEvents.count, 1)

        _ = rpSpace.performEvents(firstEvents)

        XCTAssertTrue(rpSpace.bodies[body.id]!.isCoolingDown())
        XCTAssertTrue(rpSpace.bodies[body.id]!.executableAbilities["Strike"]!.canExecute(in: rpSpace))
        XCTAssertTrue(rpSpace.bodies[body.id]!.getPendingExecutableEvents(in: rpSpace).isEmpty)

        rpSpace.tick(RPMoment(delta: 499))
        XCTAssertTrue(rpSpace.bodies[body.id]!.getPendingExecutableEvents(in: rpSpace).isEmpty)

        rpSpace.tick(RPMoment(delta: 1))
        XCTAssertFalse(rpSpace.bodies[body.id]!.isCoolingDown())
        XCTAssertEqual(rpSpace.bodies[body.id]!.getPendingExecutableEvents(in: rpSpace).count, 1)
    }

    func test_status_effects_should_be_able_to_remove_status_effect_by_name() {
        let se = RPStatusEffect<TestRPSpace>(code: "Death", tags: ["KO"], fragments: [], duration: nil, charges: 1)
        body.applyStatusEffect(se)

        XCTAssertEqual(body.hasStatus("Death"), true)

        body.dischargeStatusEffect("KO")
        XCTAssertEqual(body.hasStatus("Death"), false)
    }

    func test_status_effects_discharges_to_remove_a_status_effect_with_multiple_charges() {
        let se = RPStatusEffect<TestRPSpace>(code: "Charge", tags: ["boost"], fragments: [], duration: nil, charges: 2)
        body.applyStatusEffect(se)

        XCTAssertEqual(body.hasStatus("Charge"), true)

        body.dischargeStatusEffect("boost")
        XCTAssertEqual(body.hasStatus("Charge"), true)

        body.dischargeStatusEffect("boost")
        XCTAssertEqual(body.hasStatus("Charge"), false)
    }
}

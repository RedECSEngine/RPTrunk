@testable import RPTrunk
import XCTest



final class EntityTests: XCTestCase {
    static var allTests = [
        ("test_should_be_able_to_have_any_stats_value_within_the_baseStats_range", test_should_be_able_to_have_any_stats_value_within_the_baseStats_range),
    ]

    var entity: RPEntity<TestRPSpace>!
    var enemy: RPEntity<TestRPSpace>!
    var rpSpace: TestRPSpace!

    override func setUp() {

        entity = RPEntity(["hp": 30])
        enemy = RPEntity(["hp": 30])
        rpSpace = TestRPSpace()

        var entityTeam = RPTeam<TestRPSpace>()
        entityTeam.add(&entity)
        var enemyTeam = RPTeam<TestRPSpace>()
        enemyTeam.add(&enemy)
        
        rpSpace.addEntity(entity)
        rpSpace.addEntity(enemy)
        rpSpace.setTeams([entityTeam, enemyTeam])
    }

    func test_should_be_able_to_have_any_stats_value_within_the_baseStats_range() {
        entity.setCurrentStats(.init(dict: [\.hp: 15, \.damage: 0]), in: rpSpace)
        XCTAssertEqual(entity.hp, 15)
        XCTAssertEqual(entity.damage, 0)
    }

    func test_should_not_be_able_to_exceed_base_stats() {
        entity.setCurrentStats(.init(dict: [\.hp: 45, \.damage: 10]), in: rpSpace)
        XCTAssertEqual(entity.hp, 30)
        XCTAssertEqual(entity.damage, 0)
    }
    
    func test_entity_stats_are_sum_of_components() {
        let sword = RPItem<TestRPSpace>(components: [
            Component(stats: .init(dict: [\.damage: 10]))
        ])
        let helmet = RPItem<TestRPSpace>(components: [
            Component(stats: .init(dict: [\.damage: 5]))
        ])
        
        rpSpace.items[sword.id] = sword
        rpSpace.items[helmet.id] = helmet
        entity.body.wornItems = [sword.id, helmet.id]
        
        XCTAssertEqual(entity.getTotalStats(in: rpSpace).damage, 15)
        
        entity.setCurrentStats(.init(dict: [\.damage: 100]), in: rpSpace)
        XCTAssertEqual(entity.damage, 15)
    }

    func test_passive_abilities_should_trigger_on_event_occurrences() {
        let ability = Ability<TestRPSpace>(name: "Test")
        rpSpace.entities[entity.id]?.addPassiveAbility(ability, conditional: .always)

        let enemyAbility = Ability<TestRPSpace>(name: "enemyAbility")
        let fakeEvent = Event(initiator: enemy.id, ability: enemyAbility, rpSpace: rpSpace)

        _ = fakeEvent.execute(in: &rpSpace)
        let reactionEvents = rpSpace.entities[entity.id]?.getPendingPassiveEvents(in: rpSpace)
        XCTAssertEqual(reactionEvents?.count, 1)
        XCTAssertEqual(reactionEvents?.first?.ability, ability)
    }

    func test_status_effects_should_be_able_to_remove_status_effect_by_name() {
        let se = StatusEffect<TestRPSpace>(name: "Death", tags: ["KO"], components: [], duration: nil, charges: 1)
        entity.applyStatusEffect(se)

        XCTAssertEqual(entity.hasStatus("Death"), true)

        entity.dischargeStatusEffect("KO")
        XCTAssertEqual(entity.hasStatus("Death"), false)
    }

    func test_status_effects_discharges_to_remove_a_status_effect_with_multiple_charges() {
        let se = StatusEffect<TestRPSpace>(name: "Charge", tags: ["boost"], components: [], duration: nil, charges: 2)
        entity.applyStatusEffect(se)

        XCTAssertEqual(entity.hasStatus("Charge"), true)

        entity.dischargeStatusEffect("boost")
        XCTAssertEqual(entity.hasStatus("Charge"), true)

        entity.dischargeStatusEffect("boost")
        XCTAssertEqual(entity.hasStatus("Charge"), false)
    }
}

@testable import RPTrunk
import XCTest

final class EntityTests: XCTestCase {
    static var allTests = [
        ("test_should_be_able_to_have_any_stats_value_within_the_baseStats_range", test_should_be_able_to_have_any_stats_value_within_the_baseStats_range),
    ]

    var entity: Entity!
    var enemy: Entity!
    var rpSpace: RPSpace!

    override func setUp() {
        let env = RPGameEnvironment(delegate: DefaultGame())
        RPGameEnvironment.pushEnvironment(env)

        entity = Entity(["hp": 30])
        enemy = Entity(["hp": 30])
        rpSpace = RPSpace()

        let entityTeam = Team(id: UUID().uuidString)
        entityTeam.add(entity)
        let enemyTeam = Team(id: UUID().uuidString)
        enemyTeam.add(enemy)
        rpSpace.setTeams([entityTeam, enemyTeam])
    }

    func test_should_be_able_to_have_any_stats_value_within_the_baseStats_range() {
        entity.setCurrentStats(["hp": 15])
        XCTAssertEqual(entity["hp"], 15)
    }

    func test_should_not_be_able_to_exceed_base_stats() {
        entity.setCurrentStats(["hp": 45])
        XCTAssertEqual(entity["hp"], 30)
    }

    func test_passive_abilities_should_trigger_on_event_occurences() {
        let ability = Ability(name: "Test")
        entity.addPassiveAbility(ability, conditional: .always)

        let enemyAbility = Ability(name: "enemyAbility")
        let fakeEvent = Event(initiator: enemy, ability: enemyAbility, rpSpace: rpSpace)

        _ = fakeEvent.execute(in: rpSpace)
        let reactionEvents = entity.getPendingPassiveEvents(in: rpSpace)
        XCTAssertEqual(reactionEvents.count, 1)
        XCTAssertEqual(reactionEvents.first!.ability, ability)
    }

    func test_status_effects_should_be_able_to_remove_status_effect_by_name() {
        let se = StatusEffect(name: "Death", labels: ["KO"], components: [], duration: nil, charges: 1)
        entity.applyStatusEffect(se)

        XCTAssertEqual(entity.hasStatus("Death"), true)

        entity.dischargeStatusEffect("KO")
        XCTAssertEqual(entity.hasStatus("Death"), false)
    }

    func test_status_effects_discharges_to_remove_a_status_effect_with_multiple_charges() {
        let se = StatusEffect(name: "Charge", labels: ["boost"], components: [], duration: nil, charges: 2)
        entity.applyStatusEffect(se)

        XCTAssertEqual(entity.hasStatus("Charge"), true)

        entity.dischargeStatusEffect("boost")
        XCTAssertEqual(entity.hasStatus("Charge"), true)

        entity.dischargeStatusEffect("boost")
        XCTAssertEqual(entity.hasStatus("Charge"), false)
    }
}

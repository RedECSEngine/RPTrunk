@testable import RPTrunk
import XCTest

final class TriggerTests: XCTestCase {
    var rpSpace: TestRPSpace!
    var hero: RPBody<TestRPSpace>!
    var villain: RPBody<TestRPSpace>!
    var bystander: RPBody<TestRPSpace>!

    override func setUp() {
        TestRPSpace.resetTestHooks()

        hero = RPBody(["hp": 30])
        hero.id = "hero"
        villain = RPBody(["hp": 30])
        villain.id = "villain"
        bystander = RPBody(["hp": 30])
        bystander.id = "bystander"

        rpSpace = TestRPSpace()

        var heroTeam = RPTeam<TestRPSpace>()
        heroTeam.add(&hero)
        heroTeam.add(&bystander)
        var villainTeam = RPTeam<TestRPSpace>()
        villainTeam.add(&villain)
        heroTeam.enemies = [villainTeam.id]
        villainTeam.enemies = [heroTeam.id]

        rpSpace.addBody(hero)
        rpSpace.addBody(villain)
        rpSpace.addBody(bystander)
        rpSpace.setTeams([heroTeam, villainTeam])

        rpSpace.bodies["hero"]?.targets = ["villain"]
        rpSpace.bodies["villain"]?.targets = ["hero"]
    }

    override func tearDown() {
        TestRPSpace.resetTestHooks()
    }

    private func ability(
        _ code: String,
        tags: Set<RPAbilityTag> = [],
        target: RPTargeting<TestRPSpace>? = nil
    ) -> RPAbility<TestRPSpace> {
        RPAbility<TestRPSpace>(
            code: code,
            tags: tags,
            fragments: target.map { [RPFragment(targetType: $0)] } ?? []
        )
    }

    private func attack(tags: Set<RPAbilityTag> = []) -> RPEvent<TestRPSpace> {
        RPEvent(
            initiator: "villain",
            ability: ability("Attack", tags: tags, target: RPTargeting(.enemy, .always, sort: .highestThreat)),
            rpSpace: rpSpace
        )
    }

    private func addTrigger(
        to bodyId: RPBodyId,
        _ trigger: RPTrigger<TestRPSpace>
    ) {
        rpSpace.bodies[bodyId]?.addTrigger(trigger)
    }

    func testPostEventWakesForABodyWithNoPartInTheEvent() {
        addTrigger(to: "bystander", RPTrigger(
            triggerType: .postEvent,
            targeting: RPTargeting(.oneself, .always),
            ability: ability("Notice"),
            cooldown: 1000
        ))

        let chain = rpSpace.forecast(attack())

        XCTAssertEqual(chain.reactions.count, 1)
        XCTAssertEqual(chain.reactions.first?.event.initiator, "bystander")
    }

    func testPostEventInitiatedOnlyWakesForTheOwnersOwnEvent() {
        addTrigger(to: "hero", RPTrigger(
            triggerType: .postEventInitiated,
            targeting: RPTargeting(.oneself, .always),
            ability: ability("Follow Up"),
            cooldown: 1000
        ))

        XCTAssertTrue(
            rpSpace.forecast(attack()).reactions.isEmpty,
            "hero was the target, not the initiator"
        )

        let heroSwing = RPEvent(
            initiator: "hero",
            ability: ability("Swing", target: RPTargeting(.enemy, .always, sort: .highestThreat)),
            rpSpace: rpSpace
        )
        XCTAssertEqual(rpSpace.forecast(heroSwing).reactions.count, 1)
    }

    func testPostEventTargetedOnlyWakesWhenTheOwnerIsNamed() {
        addTrigger(to: "bystander", RPTrigger(
            triggerType: .postEventTargeted,
            targeting: RPTargeting(.oneself, .always),
            ability: ability("Flinch"),
            cooldown: 1000
        ))

        XCTAssertTrue(
            rpSpace.forecast(attack()).reactions.isEmpty,
            "the attack named hero, not bystander"
        )

        addTrigger(to: "hero", RPTrigger(
            triggerType: .postEventTargeted,
            targeting: RPTargeting(.oneself, .always),
            ability: ability("Brace"),
            cooldown: 1000
        ))
        let chain = rpSpace.forecast(attack())
        XCTAssertEqual(chain.reactions.count, 1)
        XCTAssertEqual(chain.reactions.first?.event.initiator, "hero")
    }

    func testAbilityTagsFilterTheWakingEvent() {
        addTrigger(to: "hero", RPTrigger(
            triggerType: .postEventTargeted,
            abilityTags: ["physical"],
            targeting: RPTargeting(.oneself, .always),
            ability: ability("Retaliate"),
            cooldown: 1000
        ))

        XCTAssertEqual(rpSpace.forecast(attack(tags: ["physical"])).reactions.count, 1)
        XCTAssertTrue(rpSpace.forecast(attack(tags: ["magical"])).reactions.isEmpty)
    }

    func testEmptyAbilityTagsMatchEveryAbilityIncludingUntaggedOnes() {
        addTrigger(to: "hero", RPTrigger(
            triggerType: .postEventTargeted,
            targeting: RPTargeting(.oneself, .always),
            ability: ability("Retaliate"),
            cooldown: 1000
        ))

        XCTAssertEqual(
            rpSpace.forecast(attack()).reactions.count,
            1,
            "an untagged ability still matches a trigger that declares no tags"
        )
        XCTAssertEqual(rpSpace.forecast(attack(tags: ["magical"])).reactions.count, 1)
    }

    func testInitiatorTargetingAimsAtTheAttacker() {
        addTrigger(to: "hero", RPTrigger(
            triggerType: .postEventTargeted,
            targeting: RPTargeting(.initiator, .always),
            ability: ability("Shield Burn"),
            cooldown: 1000
        ))

        let chain = rpSpace.forecast(attack())
        XCTAssertEqual(chain.reactions.first?.event.targets, ["villain"])
    }

    func testInitiatorTargetingReachesABodyOutsideEngagementRange() {
        rpSpace.bodies["hero"]?.targets = []

        addTrigger(to: "hero", RPTrigger(
            triggerType: .postEventTargeted,
            targeting: RPTargeting(.initiator, .always),
            ability: ability("Shield Burn"),
            cooldown: 1000
        ))

        XCTAssertEqual(
            rpSpace.forecast(attack()).reactions.first?.event.targets,
            ["villain"],
            "the initiator is given, not searched for within body.targets"
        )
    }

    func testInitiatorTargetingYieldsNothingWithoutAnInitiator() {
        addTrigger(to: "hero", RPTrigger(
            triggerType: .postEventTargeted,
            targeting: RPTargeting(.initiator, .always),
            ability: ability("Shield Burn"),
            cooldown: 1000
        ))

        let gameMasterEvent = RPEvent<TestRPSpace>(
            ability: ability("Trap"),
            targets: ["hero"]
        )
        XCTAssertNil(gameMasterEvent.initiator)
        XCTAssertTrue(rpSpace.forecast(gameMasterEvent).reactions.isEmpty)
    }

    func testInitiatorTargetingYieldsNothingWhenTheInitiatorIsTheOwner() {
        addTrigger(to: "hero", RPTrigger(
            triggerType: .postEvent,
            targeting: RPTargeting(.initiator, .always),
            ability: ability("Shield Burn"),
            cooldown: 1000
        ))

        let selfInflicted = RPEvent(
            category: .periodicEffect(name: "Bleed"),
            initiator: "hero",
            ability: ability("Bleed", target: RPTargeting(.oneself, .always)),
            rpSpace: rpSpace
        )

        XCTAssertTrue(
            rpSpace.forecast(selfInflicted).reactions.isEmpty,
            "a bearer's own damage-over-time must not proc their own shield"
        )
    }

    func testInitiatorTargetingHonoursItsConditional() {
        addTrigger(to: "hero", RPTrigger(
            triggerType: .postEventTargeted,
            targeting: try! RPTargeting<TestRPSpace>.fromString("among: initiator, when: hp < 10"),
            ability: ability("Execute"),
            cooldown: 1000
        ))

        XCTAssertTrue(
            rpSpace.forecast(attack()).reactions.isEmpty,
            "villain is at full health"
        )

        rpSpace.bodies["villain"]?.setCurrentStats(.init(dict: [\.hp: 5]))
        XCTAssertEqual(rpSpace.forecast(attack()).reactions.count, 1)
    }

    func testTheOverrideWinsOverTheAbilitysOwnTargeting() {
        let selfAimed = ability("Reaction", target: RPTargeting(.oneself, .always))

        addTrigger(to: "hero", RPTrigger(
            triggerType: .postEventTargeted,
            targeting: RPTargeting(.initiator, .always),
            ability: selfAimed,
            cooldown: 1000
        ))

        XCTAssertEqual(rpSpace.forecast(attack()).reactions.first?.event.targets, ["villain"])
    }

    func testNilOverrideFallsThroughToTheAbilitysOwnTargeting() {
        let selfAimed = ability("Reaction", target: RPTargeting(.oneself, .always))

        addTrigger(to: "hero", RPTrigger(
            triggerType: .postEventTargeted,
            ability: selfAimed,
            cooldown: 1000
        ))

        XCTAssertEqual(rpSpace.forecast(attack()).reactions.first?.event.targets, ["hero"])
    }

    func testAnOverrideResolvingToNothingProducesNoNodeAndSpendsNothing() {
        addTrigger(to: "hero", RPTrigger(
            triggerType: .postEventTargeted,
            targeting: try! RPTargeting<TestRPSpace>.fromString("among: self, when: hp < 1"),
            ability: ability("Die"),
            cooldown: 1000
        ))

        var rolls = 0
        TestRPSpace.chanceRule = { _ in
            rolls += 1
            return true
        }

        let chain = rpSpace.forecast(attack())

        XCTAssertTrue(chain.reactions.isEmpty)
        XCTAssertEqual(rolls, 0, "a trigger that cannot produce a target must not consume a roll")
        XCTAssertTrue(
            rpSpace.bodies["hero"]!.triggerCooldowns.isEmpty,
            "nor spend its cooldown"
        )
    }

    func testASubAbilityAlsoReachesTheAttacker() {
        var reaction = ability("Shield Burn", target: RPTargeting(.oneself, .always))
        reaction.subAbilities = [ability("Scorch", target: RPTargeting(.initiator, .always))]

        addTrigger(to: "hero", RPTrigger(
            triggerType: .postEventTargeted,
            ability: reaction,
            cooldown: 1000
        ))

        let forecastedEvent = rpSpace.forecast(attack()).reactions.first
        XCTAssertEqual(forecastedEvent?.event.targets, ["hero"], "the reaction itself is self-aimed")
        XCTAssertEqual(
            forecastedEvent?.event.subEvents.first?.targets,
            ["villain"],
            "its sub-ability resolves its own targeting and still sees the triggering event"
        )
    }

    private func cache(
        abilities: [String: RPAbilityJSON<TestRPSpace>],
        statusEffects: [String: RPStatusEffectJSON<TestRPSpace>]
    ) throws -> RPCache<TestRPSpace> {
        let cache = RPCache<TestRPSpace>()
        try cache.load(.init(abilities: abilities, statusEffects: statusEffects))
        return cache
    }

    func testLoadRejectsInitiatorTargetingOnPostEventInitiated() throws {
        XCTAssertThrowsError(
            try cache(
                abilities: ["ability.retaliate": .init(cooldown: nil)],
                statusEffects: ["status-effect.aura": .init(triggers: [
                    .init(
                        triggerType: "postEventInitiated",
                        target: "among: initiator",
                        ability: "ability.retaliate"
                    ),
                ])]
            )
        ) { error in
            guard case let RPCache<TestRPSpace>.CacheError.invalidFormat(message) = error else {
                return XCTFail("expected invalidFormat, got \(error)")
            }
            XCTAssertTrue(message.contains("postEventInitiated"), message)
        }
    }

    func testLoadRejectsAnUnrecognizedTriggerType() throws {
        XCTAssertThrowsError(
            try cache(
                abilities: ["ability.retaliate": .init(cooldown: nil)],
                statusEffects: ["status-effect.aura": .init(triggers: [
                    .init(triggerType: "whenever", ability: "ability.retaliate"),
                ])]
            )
        ) { error in
            guard case let RPCache<TestRPSpace>.CacheError.invalidFormat(message) = error else {
                return XCTFail("expected invalidFormat, got \(error)")
            }
            XCTAssertTrue(message.contains("whenever"), message)
        }
    }

    func testStatusEffectTriggersResolveRegardlessOfLoadOrder() throws {
        let loaded = try cache(
            abilities: ["ability.retaliate": .init(cooldown: nil)],
            statusEffects: ["status-effect.aura": .init(triggers: [
                .init(
                    triggerType: "postEventTargeted",
                    abilityTags: ["physical"],
                    target: "among: initiator",
                    ability: "ability.retaliate",
                    cooldown: 1500
                ),
            ])]
        )

        let aura = try XCTUnwrap(loaded.statusEffects["status-effect.aura"])
        XCTAssertEqual(aura.triggers.count, 1)
        XCTAssertEqual(aura.triggers.first?.ability.code, "ability.retaliate")
        XCTAssertEqual(aura.triggers.first?.abilityTags, ["physical"])
        XCTAssertEqual(aura.triggers.first?.targeting?.pool, .initiator)
        XCTAssertEqual(aura.triggers.first?.cooldown, 1500)
        XCTAssertEqual(aura.triggers.first?.chancePercent, RPChance.certain)
    }
}

@testable import RPTrunk
import XCTest

final class TriggerTests: XCTestCase {
    var rpSpace: TestRPSpace!
    var hero: RPBody<TestRPSpace>!
    var villain: RPBody<TestRPSpace>!
    var bystander: RPBody<TestRPSpace>!

    /// Two hostile teams with `bystander` on the hero's side, so `postEvent`
    /// can be told apart from the role-scoped wake modes.
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

    /// An attack by `villain` naming `hero` — the event every trigger here answers.
    private func attack(tags: Set<RPAbilityTag> = []) -> RPEvent<TestRPSpace> {
        RPEvent(
            initiator: "villain",
            ability: ability("Attack", tags: tags, target: RPTargeting(.singleEnemy, .always)),
            rpSpace: rpSpace
        )
    }

    private func addTrigger(
        to bodyId: RPBodyId,
        _ trigger: RPTrigger<TestRPSpace>
    ) {
        rpSpace.bodies[bodyId]?.addTrigger(trigger)
    }

    /// `postEvent` is space-wide: a bystander reacts to a fight it isn't in.
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

    /// Being hit is not initiating, so the same body wakes only when it acts.
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
            ability: ability("Swing", target: RPTargeting(.singleEnemy, .always)),
            rpSpace: rpSpace
        )
        XCTAssertEqual(rpSpace.forecast(heroSwing).reactions.count, 1)
    }

    /// Only the body the event names reacts; an ally standing by does not.
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

    /// A shield answers the damage type it declares and ignores the rest.
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

    /// No declared tags means no filter — the empty-subset identity, pinned so a
    /// rewrite can't quietly invert it into matching nothing.
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

    /// The whole point of the selector: retaliate against whoever swung.
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

    /// The initiator is handed over, not searched for, so a shield answers an
    /// attacker who struck from beyond reach.
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

    /// A scripted event has nobody to blame, so there is nothing to hit back at.
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

    /// Self-inflicted damage must not proc the bearer's own shield every pulse.
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

    /// The targeting conditional filters the attacker like any other target.
    func testInitiatorTargetingHonoursItsConditional() {
        addTrigger(to: "hero", RPTrigger(
            triggerType: .postEventTargeted,
            targeting: try! RPTargeting<TestRPSpace>.fromString("initiator:hp < 10"),
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

    /// The override is what lets one ability serve a cast and a reaction.
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

    /// Without an override the ability keeps its own aim.
    func testNilOverrideFallsThroughToTheAbilitysOwnTargeting() {
        let selfAimed = ability("Reaction", target: RPTargeting(.oneself, .always))

        addTrigger(to: "hero", RPTrigger(
            triggerType: .postEventTargeted,
            ability: selfAimed,
            cooldown: 1000
        ))

        XCTAssertEqual(rpSpace.forecast(attack()).reactions.first?.event.targets, ["hero"])
    }

    /// An empty target set is the trigger's gate, and gating must cost nothing —
    /// no cooldown, no charge, and above all no draw from the seeded stream.
    func testAnOverrideResolvingToNothingProducesNoNodeAndSpendsNothing() {
        addTrigger(to: "hero", RPTrigger(
            triggerType: .postEventTargeted,
            targeting: try! RPTargeting<TestRPSpace>.fromString("oneself:hp < 1"),
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

    /// Sub-abilities resolve their own aim but still see the triggering event,
    /// which an explicit target set would not have carried to them.
    func testASubAbilityAlsoReachesTheAttacker() {
        var reaction = ability("Shield Burn", target: RPTargeting(.oneself, .always))
        reaction.subAbilities = [ability("Scorch", target: RPTargeting(.initiator, .always))]

        addTrigger(to: "hero", RPTrigger(
            triggerType: .postEventTargeted,
            ability: reaction,
            cooldown: 1000
        ))

        let node = rpSpace.forecast(attack()).reactions.first
        XCTAssertEqual(node?.event.targets, ["hero"], "the reaction itself is self-aimed")
        XCTAssertEqual(
            node?.event.subEvents.first?.targets,
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

    /// The one combination that could never fire fails loudly at load.
    func testLoadRejectsInitiatorTargetingOnPostEventInitiated() throws {
        XCTAssertThrowsError(
            try cache(
                abilities: ["ability.retaliate": .init(cooldown: nil)],
                statusEffects: ["status-effect.aura": .init(triggers: [
                    .init(
                        triggerType: "postEventInitiated",
                        target: "initiator",
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

    /// A misspelled wake mode is an error, never a silently inert trigger.
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

    /// Status effects load before abilities, so a trigger's ability is wired in a
    /// later pass — this is that pass working.
    func testStatusEffectTriggersResolveRegardlessOfLoadOrder() throws {
        let loaded = try cache(
            abilities: ["ability.retaliate": .init(cooldown: nil)],
            statusEffects: ["status-effect.aura": .init(triggers: [
                .init(
                    triggerType: "postEventTargeted",
                    abilityTags: ["physical"],
                    target: "initiator",
                    ability: "ability.retaliate",
                    cooldown: 1500
                ),
            ])]
        )

        let aura = try XCTUnwrap(loaded.statusEffects["status-effect.aura"])
        XCTAssertEqual(aura.triggers.count, 1)
        XCTAssertEqual(aura.triggers.first?.ability.code, "ability.retaliate")
        XCTAssertEqual(aura.triggers.first?.abilityTags, ["physical"])
        XCTAssertEqual(aura.triggers.first?.targeting?.type, .initiator)
        XCTAssertEqual(aura.triggers.first?.cooldown, 1500)
        XCTAssertEqual(aura.triggers.first?.chancePercent, RPChance.certain)
    }
}

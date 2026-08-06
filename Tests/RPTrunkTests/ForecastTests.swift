@testable import RPTrunk
import XCTest

final class ForecastTests: XCTestCase {
    var rpSpace: TestRPSpace!
    var hero: RPBody<TestRPSpace>!
    var villain: RPBody<TestRPSpace>!

    override func setUp() {
        TestRPSpace.resetTestHooks()

        hero = RPBody(["hp": 30])
        hero.id = "hero"
        villain = RPBody(["hp": 30])
        villain.id = "villain"

        rpSpace = TestRPSpace()

        var heroTeam = RPTeam<TestRPSpace>()
        heroTeam.add(&hero)
        var villainTeam = RPTeam<TestRPSpace>()
        villainTeam.add(&villain)
        heroTeam.enemies = [villainTeam.id]
        villainTeam.enemies = [heroTeam.id]

        rpSpace.addBody(hero)
        rpSpace.addBody(villain)
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
        target: RPTargeting<TestRPSpace>? = nil,
        statusEffects: [RPStatusEffect<TestRPSpace>] = []
    ) -> RPAbility<TestRPSpace> {
        var fragments: [RPFragment<TestRPSpace>] = []
        if let target {
            fragments.append(RPFragment(targetType: target))
        }
        if !statusEffects.isEmpty {
            fragments.append(RPFragment(statusEffects: statusEffects))
        }
        return RPAbility<TestRPSpace>(code: code, tags: tags, fragments: fragments)
    }

    private func attack() -> RPEvent<TestRPSpace> {
        RPEvent(
            initiator: "villain",
            ability: ability("Attack", tags: ["physical"], target: RPTargeting(.enemy, .always, sort: .highestThreat)),
            rpSpace: rpSpace
        )
    }

    private func retaliation(cooldown: RPTimeIncrement, chancePercent: RPValue = RPChance.certain)
        -> RPTrigger<TestRPSpace>
    {
        RPTrigger(
            triggerType: .postEventTargeted,
            abilityTags: ["physical"],
            targeting: RPTargeting(.initiator, .always),
            ability: ability("Shield Burn"),
            chancePercent: chancePercent,
            cooldown: cooldown
        )
    }

    private func useFlatDamage(_ amount: Int) {
        TestRPSpace.conflictRule = { _, _, target, _ in
            RPConflictResult(bodyId: target, .init(dict: [\.hp: -amount]))
        }
    }

    func testTheForecastRollsExactlyOncePerEventAndApplyReusesIt() {
        var rolls = 0
        TestRPSpace.conflictRule = { _, _, target, _ in
            rolls += 1
            return RPConflictResult(bodyId: target, .init(dict: [\.hp: -7]))
        }

        let event = attack()
        let chain = rpSpace.forecast(event)
        let rollsAfterForecast = rolls

        XCTAssertEqual(chain.forecastedEvents.count, 1)
        XCTAssertGreaterThan(rollsAfterForecast, 0)

        let recorded = chain.root.result.effects.first { $0.body == "hero" }?.change.hp
        XCTAssertEqual(recorded, -7)

        chain.root.event.apply(chain.root.result, in: &rpSpace)

        XCTAssertEqual(
            rolls,
            rollsAfterForecast,
            "applying a forecast result must not roll again"
        )
        XCTAssertEqual(rpSpace.bodies["hero"]?.hp, 23)
    }

    func testApplyReproducesExactlyWhatTheForecastRecorded() {
        var next = -1
        TestRPSpace.conflictRule = { _, _, target, _ in
            next -= 1
            return RPConflictResult(bodyId: target, .init(dict: [\.hp: next]))
        }

        let chain = rpSpace.forecast(attack())
        let forecastHP = chain.root.result.effects.first { $0.body == "hero" }?.change.hp

        chain.root.event.apply(chain.root.result, in: &rpSpace)

        XCTAssertEqual(
            rpSpace.bodies["hero"]!.hp,
            30 + forecastHP!,
            "a re-roll would have produced a different, larger loss"
        )
    }

    func testTheChainIsOrderedRootFirstThenReactions() {
        useFlatDamage(1)
        rpSpace.bodies["hero"]?.addTrigger(retaliation(cooldown: 1500))

        let chain = rpSpace.forecast(attack())

        XCTAssertEqual(chain.forecastedEvents.count, 2)
        XCTAssertEqual(chain.root.event.ability.code, "Attack")
        XCTAssertEqual(chain.root.depth, 0)
        XCTAssertEqual(chain.reactions.first?.event.ability.code, "Shield Burn")
        XCTAssertEqual(chain.reactions.first?.depth, 1)
        XCTAssertFalse(chain.wasTruncated)
    }

    func testAReactionRecordsTheTriggerItCameFrom() {
        useFlatDamage(1)
        rpSpace.bodies["hero"]?.addTrigger(retaliation(cooldown: 1500))

        let forecastedEvent = rpSpace.forecast(attack()).reactions.first
        guard case let .trigger(owner, source, code, chancePercent) = forecastedEvent?.origin else {
            return XCTFail("expected a trigger origin, got \(String(describing: forecastedEvent?.origin))")
        }
        XCTAssertEqual(owner, "hero")
        XCTAssertEqual(source, .body)
        XCTAssertEqual(code, "Shield Burn")
        XCTAssertEqual(chancePercent, RPChance.certain)
        XCTAssertEqual(forecastedEvent?.wasChanceGated, false)
    }

    func testAChanceGatedEventIsMarkedAndItsChainStillExplored() {
        useFlatDamage(1)
        TestRPSpace.chanceRule = { _ in true }

        rpSpace.bodies["hero"]?.addTrigger(
            retaliation(cooldown: 1500, chancePercent: 3500)
        )
        rpSpace.bodies["villain"]?.addTrigger(RPTrigger(
            triggerType: .postEventTargeted,
            targeting: RPTargeting(.oneself, .always),
            ability: ability("Wince"),
            cooldown: 1500
        ))

        let chain = rpSpace.forecast(attack())

        XCTAssertEqual(chain.forecastedEvents.count, 3, "the chain past a chance-gated one is explored normally")
        let gated = chain.forecastedEvents.first { $0.event.ability.code == "Shield Burn" }
        XCTAssertTrue(gated!.wasChanceGated)
        XCTAssertFalse(chain.root.wasChanceGated)
    }

    func testAFailedChanceRollProducesNoForecastedEvent() {
        useFlatDamage(1)
        TestRPSpace.chanceRule = { _ in false }
        rpSpace.bodies["hero"]?.addTrigger(retaliation(cooldown: 1500, chancePercent: 3500))

        XCTAssertTrue(rpSpace.forecast(attack()).reactions.isEmpty)
    }

    func testACooldownStopsATriggerFiringTwiceInOneChain() {
        useFlatDamage(1)
        rpSpace.bodies["hero"]?.addTrigger(retaliation(cooldown: 1500))
        rpSpace.bodies["villain"]?.addTrigger(RPTrigger(
            triggerType: .postEventTargeted,
            targeting: RPTargeting(.initiator, .always),
            ability: ability("Riposte", tags: ["physical"]),
            cooldown: 1500
        ))

        let chain = rpSpace.forecast(attack())

        XCTAssertFalse(chain.wasTruncated)
        XCTAssertEqual(
            chain.forecastedEvents.filter { $0.event.ability.code == "Shield Burn" }.count,
            1,
            "hero's shield is on cooldown by the time the riposte lands on them"
        )
    }

    func testARunawayChainIsTruncatedAndReported() {
        useFlatDamage(1)
        rpSpace.bodies["hero"]?.addTrigger(RPTrigger(
            triggerType: .postEvent,
            targeting: RPTargeting(.oneself, .always),
            ability: ability("Echo")
        ))

        let chain = rpSpace.forecast(attack())

        XCTAssertTrue(chain.wasTruncated, "a zero-cooldown self-feeding trigger must be bounded")
        XCTAssertEqual(chain.forecastedEvents.count, TestRPSpace.maximumForecastedEvents)
    }

    private func aura(charges: Int?, cooldown: RPTimeIncrement) -> RPStatusEffect<TestRPSpace> {
        var effect = RPStatusEffect<TestRPSpace>(
            code: "status-effect.burning-shield",
            tags: ["shielded"],
            duration: nil,
            charges: charges
        )
        effect.triggers = [retaliation(cooldown: cooldown)]
        return effect
    }

    func testAStatusOwnedTriggerCooldownLivesOnTheEffectNotTheBody() {
        useFlatDamage(1)
        rpSpace.bodies["hero"]?.applyStatusEffect(aura(charges: nil, cooldown: 1500))

        var simulated = rpSpace!
        let chain = simulated.forecast(attack())
        XCTAssertEqual(chain.reactions.count, 1)

        simulated.spendTrigger(
            owner: "hero",
            source: .statusEffect("status-effect.burning-shield"),
            of: chain.reactions.first!.event
        )

        XCTAssertTrue(
            simulated.bodies["hero"]!.triggerCooldowns.isEmpty,
            "a status effect never writes trigger state onto its bearer"
        )
        XCTAssertEqual(
            simulated.bodies["hero"]!
                .statusEffects["status-effect.burning-shield"]!
                .triggerCooldowns["Shield Burn"],
            1500
        )
    }

    func testTwoBearersOfTheSameAuraCoolDownIndependently() {
        useFlatDamage(1)
        rpSpace.bodies["hero"]?.applyStatusEffect(aura(charges: nil, cooldown: 1500))
        rpSpace.bodies["villain"]?.applyStatusEffect(aura(charges: nil, cooldown: 1500))

        rpSpace.spendTrigger(
            owner: "hero",
            source: .statusEffect("status-effect.burning-shield"),
            of: RPEvent(initiator: "hero", ability: ability("Shield Burn"), targets: ["villain"], rpSpace: rpSpace)
        )

        XCTAssertNotNil(
            rpSpace.bodies["hero"]!.statusEffects["status-effect.burning-shield"]!
                .triggerCooldowns["Shield Burn"]
        )
        XCTAssertNil(
            rpSpace.bodies["villain"]!.statusEffects["status-effect.burning-shield"]!
                .triggerCooldowns["Shield Burn"],
            "villain's own copy of the aura is untouched"
        )
    }

    func testReapplyingAStatusClearsItsTriggerCooldowns() {
        useFlatDamage(1)
        let effect = aura(charges: nil, cooldown: 1500)
        rpSpace.bodies["hero"]?.applyStatusEffect(effect)
        rpSpace.spendTrigger(
            owner: "hero",
            source: .statusEffect("status-effect.burning-shield"),
            of: RPEvent(initiator: "hero", ability: ability("Shield Burn"), targets: ["villain"], rpSpace: rpSpace)
        )
        XCTAssertFalse(
            rpSpace.bodies["hero"]!.statusEffects["status-effect.burning-shield"]!
                .triggerCooldowns.isEmpty
        )

        rpSpace.bodies["hero"]?.applyStatusEffect(effect)

        XCTAssertTrue(
            rpSpace.bodies["hero"]!.statusEffects["status-effect.burning-shield"]!
                .triggerCooldowns.isEmpty
        )
    }

    func testAChargedAuraIsSpentDownAndRemoved() {
        useFlatDamage(1)
        rpSpace.bodies["hero"]?.applyStatusEffect(aura(charges: 2, cooldown: 0))

        let burn = RPEvent(
            initiator: "hero",
            ability: ability("Shield Burn"),
            targets: ["villain"],
            rpSpace: rpSpace
        )

        rpSpace.spendTrigger(owner: "hero", source: .statusEffect("status-effect.burning-shield"), of: burn)
        XCTAssertNotNil(rpSpace.bodies["hero"]!.statusEffects["status-effect.burning-shield"])

        rpSpace.spendTrigger(owner: "hero", source: .statusEffect("status-effect.burning-shield"), of: burn)
        XCTAssertNil(
            rpSpace.bodies["hero"]!.statusEffects["status-effect.burning-shield"],
            "the aura drops off once its last charge is spent"
        )
    }

    func testAChargedAuraTerminatesItsOwnChain() {
        useFlatDamage(1)
        rpSpace.bodies["hero"]?.applyStatusEffect(aura(charges: 1, cooldown: 0))
        rpSpace.bodies["villain"]?.addTrigger(RPTrigger(
            triggerType: .postEventTargeted,
            targeting: RPTargeting(.initiator, .always),
            ability: ability("Riposte", tags: ["physical"]),
            cooldown: 1500
        ))

        let chain = rpSpace.forecast(attack())

        XCTAssertFalse(chain.wasTruncated)
        XCTAssertEqual(chain.forecastedEvents.filter { $0.event.ability.code == "Shield Burn" }.count, 1)
    }

    func testBodyTriggerCooldownsTickDownAndClear() {
        rpSpace.bodies["hero"]?.addTrigger(retaliation(cooldown: 1500))
        rpSpace.spendTrigger(
            owner: "hero",
            source: .body,
            of: RPEvent(initiator: "hero", ability: ability("Shield Burn"), targets: ["villain"], rpSpace: rpSpace)
        )
        XCTAssertEqual(rpSpace.bodies["hero"]!.triggerCooldowns["Shield Burn"], 1500)

        rpSpace.tick(.init(delta: 1400))
        XCTAssertEqual(rpSpace.bodies["hero"]!.triggerCooldowns["Shield Burn"], 100)

        rpSpace.tick(.init(delta: 100))
        XCTAssertNil(
            rpSpace.bodies["hero"]!.triggerCooldowns["Shield Burn"],
            "a passive's cooldown used never to tick at all"
        )
    }

    func testStatusOwnedTriggerCooldownsTickWithTheirEffect() {
        var effect = RPStatusEffect<TestRPSpace>(
            code: "status-effect.burning-shield",
            tags: ["shielded"],
            duration: 10000,
            charges: nil
        )
        effect.triggers = [retaliation(cooldown: 1500)]
        rpSpace.bodies["hero"]?.applyStatusEffect(effect)

        rpSpace.spendTrigger(
            owner: "hero",
            source: .statusEffect("status-effect.burning-shield"),
            of: RPEvent(initiator: "hero", ability: ability("Shield Burn"), targets: ["villain"], rpSpace: rpSpace)
        )

        rpSpace.tick(.init(delta: 1500))

        XCTAssertNil(
            rpSpace.bodies["hero"]!.statusEffects["status-effect.burning-shield"]!
                .triggerCooldowns["Shield Burn"]
        )
    }

    func testForecastingLeavesTheLiveSpaceUntouched() {
        useFlatDamage(4)
        rpSpace.bodies["hero"]?.addTrigger(retaliation(cooldown: 1500))

        let before = rpSpace!
        _ = rpSpace.forecast(attack())

        XCTAssertEqual(
            rpSpace,
            before,
            "forecast simulates against copy(); a conformance without value semantics would have mutated the live space here"
        )
    }

    func testAdditionalEventsJoinTheChain() {
        useFlatDamage(1)
        var injected = false
        TestRPSpace.additionalEventsRule = { result, space in
            guard !injected, result.event.ability.code == "Attack" else { return [] }
            injected = true
            return [RPEvent(
                initiator: "villain",
                ability: self.ability("Aftershock", target: RPTargeting(.oneself, .always)),
                rpSpace: space
            )]
        }

        let chain = rpSpace.forecast(attack())

        XCTAssertEqual(chain.forecastedEvents.count, 2)
        XCTAssertEqual(chain.reactions.first?.event.ability.code, "Aftershock")
        XCTAssertEqual(chain.reactions.first?.origin, .root)
    }
}

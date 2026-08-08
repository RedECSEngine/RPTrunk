@testable import RPTrunk
import XCTest

final class ParserTests: XCTestCase {
    var body: RPBody<TestRPSpace>!
    var enemy: RPBody<TestRPSpace>!
    var rpSpace: TestRPSpace!

    override func setUp() {
        body = RPBody(["hp": 30])
        enemy = RPBody(["hp": 30])
        body.addThreat(toward: enemy.id, amount: 1)
        rpSpace = TestRPSpace()

        var bodyTeam = RPTeam<TestRPSpace>()
        bodyTeam.add(&body)
        var enemyTeam = RPTeam<TestRPSpace>()
        enemyTeam.add(&enemy)

        rpSpace.addBody(body)
        rpSpace.addBody(enemy)
        rpSpace.setTeams([bodyTeam, enemyTeam])
    }

    private func context(_ id: RPBodyId, initiator: RPBodyId? = nil) -> RPConditionContext {
        RPConditionContext(body: id, initiator: initiator ?? id)
    }

    // MARK: - Syntax

    func testTokenClassification() throws {
        XCTAssertEqual(try ConditionTokenParser.classify("target"), .target)
        XCTAssertEqual(try ConditionTokenParser.classify("self"), .oneself)
        XCTAssertEqual(try ConditionTokenParser.classify("has"), .keyword("has", usePercent: false))
        XCTAssertEqual(try ConditionTokenParser.classify("hasAny"), .keyword("hasAny", usePercent: false))
        XCTAssertEqual(try ConditionTokenParser.classify("threat"), .threat)
        XCTAssertEqual(try ConditionTokenParser.classify("hp"), .keyword("hp", usePercent: false))
        XCTAssertEqual(try ConditionTokenParser.classify("hp%"), .keyword("hp", usePercent: true))
        XCTAssertEqual(try ConditionTokenParser.classify("Healing?"), .keyword("Healing?", usePercent: false))
        XCTAssertEqual(try ConditionTokenParser.classify("40"), .value(40))
        XCTAssertEqual(try ConditionTokenParser.classify("10%"), .percent(10))
        XCTAssertEqual(try ConditionTokenParser.classify("true"), .keyword("true", usePercent: false))
        XCTAssertEqual(try ConditionTokenParser.classify("false"), .keyword("false", usePercent: false))
    }

    func testDotNotationChainParsing() throws {
        let parsed = try parseCondition("target.hp == target.hp")
        XCTAssertEqual(parsed.orGroups.count, 1)
        XCTAssertEqual(parsed.orGroups[0].count, 1)

        let clause = parsed.orGroups[0][0]
        XCTAssertEqual(clause.lhs.tokens, [.target, .keyword("hp", usePercent: false)])
        XCTAssertEqual(clause.comparison?.op, .equal)
        XCTAssertEqual(clause.comparison?.rhs.tokens, [.target, .keyword("hp", usePercent: false)])
    }

    func testWhitespaceTolerance() throws {
        let parsed = try parseCondition("  hp    >    target.hp  ")
        XCTAssertEqual(
            parsed,
            ParsedCondition(orGroups: [[
                ConditionClause(
                    lhs: .init(tokens: [.keyword("hp", usePercent: false)]),
                    comparison: .init(op: .greaterThan, rhs: .init(tokens: [.target, .keyword("hp", usePercent: false)]))
                ),
            ]])
        )
    }

    func testConjunctionParsing() throws {
        let parsed = try parseCondition("hp > 10 && !statusAny(Healing)")
        XCTAssertEqual(parsed.orGroups.count, 1)
        XCTAssertEqual(parsed.orGroups[0].count, 2)
        XCTAssertEqual(parsed.orGroups[0][0].comparison?.op, .greaterThan)
        XCTAssertEqual(parsed.orGroups[0][1].lhs.tokens, [.tagQuery(.status, .any, ["Healing"])])
        XCTAssertNil(parsed.orGroups[0][1].comparison)
        XCTAssertTrue(parsed.orGroups[0][1].isNegated)
    }

    func testDisjunctionParsingAndPrecedence() throws {
        XCTAssertEqual(
            try printCondition(parseCondition("hp < 5||statusAny(Healing) && hp > 2")),
            "hp < 5 || statusAny(Healing) && hp > 2"
        )
        let parsed = try parseCondition("hp < 5 || statusAny(Healing) && hp > 2")
        XCTAssertEqual(parsed.orGroups.count, 2)
        XCTAssertEqual(parsed.orGroups[0].count, 1)
        XCTAssertEqual(parsed.orGroups[1].count, 2)
    }

    func testTagListParsing() throws {
        XCTAssertEqual(
            try parseCondition("uses(some.ability, some.other-ability)").orGroups[0][0].lhs.tokens,
            [.tagQuery(.uses, .all, ["some.ability", "some.other-ability"])]
        )
        XCTAssertEqual(
            try parseCondition("holdsAny( magic.fire ,magic.ice )").orGroups[0][0].lhs.tokens,
            [.tagQuery(.holds, .any, ["magic.fire", "magic.ice"])]
        )
        XCTAssertEqual(
            try parseCondition("status(target, self, threat, 40, 10%)").orGroups[0][0].lhs.tokens,
            [.tagQuery(.status, .all, ["target", "self", "threat", "40", "10%"])]
        )
    }

    func testOperatorParsing() throws {
        XCTAssertEqual(try parseCondition("hp > 1").orGroups[0][0].comparison?.op, .greaterThan)
        XCTAssertEqual(try parseCondition("hp < 1").orGroups[0][0].comparison?.op, .lessThan)
        XCTAssertEqual(try parseCondition("hp >= 1").orGroups[0][0].comparison?.op, .greaterThanOrEqual)
        XCTAssertEqual(try parseCondition("hp <= 1").orGroups[0][0].comparison?.op, .lessThanOrEqual)
        XCTAssertEqual(try parseCondition("hp == 1").orGroups[0][0].comparison?.op, .equal)
        XCTAssertEqual(try parseCondition("hp != 1").orGroups[0][0].comparison?.op, .notEqual)
    }

    private func assertParseFails(
        _ input: String,
        with expected: ConditionSyntaxError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try parseCondition(input), file: file, line: line) { error in
            XCTAssertEqual(error as? ConditionSyntaxError, expected, file: file, line: line)
        }
    }

    func testUnparseableConditionsThrowPreciseErrors() {
        assertParseFails("", with: .expectedToken)
        assertParseFails("   ", with: .expectedToken)
        assertParseFails("hp >", with: .expectedToken)
        assertParseFails("> 10", with: .expectedToken)
        assertParseFails("hp > 10 &&", with: .expectedToken)
        assertParseFails("hp > 10 ||", with: .expectedToken)
        assertParseFails("hp && hp > 1 ||", with: .expectedToken)
        assertParseFails("hp ~ 10", with: .unexpectedTrailingCharacters("~ 10"))
        assertParseFails("hp == 10 extra", with: .unexpectedTrailingCharacters("extra"))
        assertParseFails("hp >< 10", with: .unexpectedTrailingCharacters(">< 10"))
        assertParseFails("hp > 10 | hp < 5", with: .unexpectedTrailingCharacters("| hp < 5"))
        assertParseFails("%", with: .malformedPercentValue("%"))
        assertParseFails("hp > %", with: .malformedPercentValue("%"))
    }

    func testTagListParseFailures() {
        assertParseFails("statusAny", with: .expectedTagList("statusAny"))
        assertParseFails("statusAny.bleed", with: .expectedTagList("statusAny"))
        assertParseFails("status", with: .expectedTagList("status"))
        assertParseFails("uses", with: .expectedTagList("uses"))
        assertParseFails("holds.key", with: .expectedTagList("holds"))
        assertParseFails("statusAny(bleed", with: .unterminatedTagList)
        assertParseFails("statusAny()", with: .malformedTag(""))
        assertParseFails("statusAny(bleed, )", with: .malformedTag(" "))
        assertParseFails("statusAny(some tag)", with: .malformedTag("some tag"))
        assertParseFails("statusAny(a(b))", with: .unterminatedTagList)
        assertParseFails("has(bleed)", with: .unknownTagQueryKeyword("has"))
        assertParseFails("hasAny(bleed)", with: .unknownTagQueryKeyword("hasAny"))
        assertParseFails("statusAll(bleed)", with: .unknownTagQueryKeyword("statusAll"))
        assertParseFails("usesAll(magical)", with: .unknownTagQueryKeyword("usesAll"))
        assertParseFails("holdsAll(key)", with: .unknownTagQueryKeyword("holdsAll"))
        assertParseFails("poisoned(a)", with: .unknownTagQueryKeyword("poisoned"))
    }

    // MARK: - Printing

    func testPrintingIsCanonical() throws {
        XCTAssertEqual(try printCondition(parseCondition("  hp    >    target.hp  ")), "hp > target.hp")
        XCTAssertEqual(try printCondition(parseCondition("hp% > 10%")), "hp% > 10%")
        XCTAssertEqual(try printCondition(parseCondition("  statusAny( Healing )  ")), "statusAny(Healing)")
        XCTAssertEqual(
            try printCondition(parseCondition("hp > 10&&!statusAny(Healing)")),
            "hp > 10 && !statusAny(Healing)"
        )
        XCTAssertEqual(
            try printCondition(parseCondition("holds(magic.fire,magic.ice)")),
            "holds(magic.fire, magic.ice)"
        )
    }

    func testPrintedConditionRoundTrips() throws {
        let conditions = [
            "hp > target.hp",
            "hp% > 10%",
            "hp == 40",
            "!statusAny(Healing)",
            "statusAny(Dieing)",
            "hp > 10 && !statusAny(Healing)",
            "hp < 5 || statusAny(Healing) && hp > 2",
            "hp >= 5 && hp <= 100",
            "!statusAny(Healing) && !statusAny(Dieing)",
            "target.hp < 5",
            "self.hp% < hp%",
            "statusAny(bleed)",
            "status(bleed, burning)",
            "usesAny(magical)",
            "uses(some.ability, some.other-ability)",
            "holdsAny(key)",
            "holdsAny(magic.fire, magic.ice)",
            "!holds(key.gold, key.silver)",
            "target.statusAny(bleed)",
            "threat > 0",
            "target.threat == 0",
        ]
        for condition in conditions {
            let parsed = try parseCondition(condition)
            let printed = try printCondition(parsed)
            XCTAssertEqual(printed, condition, "canonical form should be stable")
            XCTAssertEqual(try parseCondition(printed), parsed, "print → parse should round-trip")
        }
    }

    // MARK: - Compilation + evaluation

    func testShouldReturnBodyTarget() throws {
        let evaluators: [ParserResultType<TestRPSpace>] = try compileOperand(.init(tokens: [.target]))

        guard case let .evaluationFunction(f) = evaluators[0] else {
            XCTFail()
            return
        }

        let result = f(.bodyResult(body: body.id), context(body.id), rpSpace)

        if case let .bodyResult(e) = result {
            XCTAssertEqual(e == enemy.id, true)
        } else {
            XCTFail()
        }
    }

    func testGetNothingWhenTargetIsNil() throws {
        let evaluators: [ParserResultType<TestRPSpace>] = try compileOperand(.init(tokens: [.target]))

        guard case let .evaluationFunction(f) = evaluators[0] else {
            XCTFail()
            return
        }

        let result = f(.bodyResult(body: enemy.id), context(enemy.id), rpSpace)
        switch result {
        case .nothing:
            break
        default:
            XCTFail()
        }
    }

    private func assertCompileFails(
        _ input: String,
        with expected: ConditionalInterpretationError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try interpretStringCondition(input) as RPConditional<TestRPSpace>.Predicate,
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(error as? ConditionalInterpretationError, expected, file: file, line: line)
        }
    }

    func testUnknownStatFailsCompilation() {
        assertCompileFails("wisdom > 10", with: .invalidSyntax(reason: "Unknown stat: wisdom"))
        assertCompileFails("hp > mana.wisdom", with: .invalidSyntax(reason: "Unknown stat: wisdom"))
    }

    func testSelfMustStartAChain() {
        assertCompileFails("hp.self > 1", with: .invalidSyntax(reason: "`self` can only start a chain"))
        XCTAssertNoThrow(
            try interpretStringCondition("self.hp > hp") as RPConditional<TestRPSpace>.Predicate
        )
        XCTAssertNoThrow(
            try interpretStringCondition("hp > self.hp") as RPConditional<TestRPSpace>.Predicate
        )
    }

    func testStatusQueriesRequireATagQuery() {
        assertCompileFails("bleed", with: .invalidSyntax(reason: "Unknown stat: bleed"))
        assertCompileFails("!bleed", with: .invalidSyntax(reason: "Unknown stat: bleed"))
        assertCompileFails("has.bleed", with: .invalidSyntax(reason: "Unknown stat: has"))
        assertCompileFails(
            "hp",
            with: .invalidSyntax(reason: "A clause without an operator must end in a tag query such as `statusAny(bleed)`")
        )
        assertCompileFails(
            "target",
            with: .invalidSyntax(reason: "A clause without an operator must end in a tag query such as `statusAny(bleed)`")
        )
    }

    func testNegationOnlyAppliesToTagQueries() {
        assertCompileFails(
            "!hp > 5",
            with: .invalidSyntax(reason: "`!` negates a tag query, not a comparison")
        )
        XCTAssertNoThrow(
            try interpretStringCondition("!usesAny(magical)") as RPConditional<TestRPSpace>.Predicate
        )
        XCTAssertNoThrow(
            try interpretStringCondition("!holds(key)") as RPConditional<TestRPSpace>.Predicate
        )
    }

    func testTagQueriesMustEndTheirChain() {
        assertCompileFails(
            "statusAny(bleed).hp > 1",
            with: .invalidSyntax(reason: "A tag query must end its chain")
        )
        XCTAssertNoThrow(
            try interpretStringCondition("target.statusAny(bleed)") as RPConditional<TestRPSpace>.Predicate
        )
        XCTAssertNoThrow(
            try interpretStringCondition("self.holdsAny(key)") as RPConditional<TestRPSpace>.Predicate
        )
    }

    func testStatsAndLogicCanReadSelfAndTargetHP() {
        var body = RPBody<TestRPSpace>(["hp": 40])
        let enemy = RPBody<TestRPSpace>(["hp": 20])
        body.addThreat(toward: enemy.id, amount: 1)

        rpSpace.addBody(body)
        rpSpace.addBody(enemy)

        let result = extractValue(context(body.id), evaluate: "hp", in: rpSpace)
        XCTAssertEqual(result, .value(40))

        let result2 = extractValue(context(body.id), evaluate: "target.hp", in: rpSpace)
        XCTAssertEqual(result2, .value(20))
    }

    func testSelfPrefixReadsTheInitiator() throws {
        var body = RPBody<TestRPSpace>(["hp": 40])
        let enemy = RPBody<TestRPSpace>(["hp": 20])

        rpSpace.addBody(body)
        rpSpace.addBody(enemy)

        let result = extractValue(context(enemy.id, initiator: body.id), evaluate: "self.hp", in: rpSpace)
        XCTAssertEqual(result, .value(40))

        let predicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("hp < self.hp")
        XCTAssertEqual(try predicate(context(enemy.id, initiator: body.id), rpSpace), true)
        XCTAssertEqual(try predicate(context(body.id, initiator: enemy.id), rpSpace), false)
    }

    func testThreatTokenReadsInitiatorThreatTowardTheChainBody() throws {
        var body = RPBody<TestRPSpace>(["hp": 40])
        let enemy = RPBody<TestRPSpace>(["hp": 20])
        body.addThreat(toward: enemy.id, amount: 7)

        rpSpace.addBody(body)
        rpSpace.addBody(enemy)

        let result = extractValue(context(enemy.id, initiator: body.id), evaluate: "threat", in: rpSpace)
        XCTAssertEqual(result, .value(7))

        let none = extractValue(context(body.id, initiator: enemy.id), evaluate: "threat", in: rpSpace)
        XCTAssertEqual(none, .value(0))
    }

    func testStatsAndLogicComparison() throws {
        var body = RPBody<TestRPSpace>(["hp": 40])
        let enemy = RPBody<TestRPSpace>(["hp": 20])
        body.addThreat(toward: enemy.id, amount: 1)

        rpSpace.addBody(body)
        rpSpace.addBody(enemy)

        let bodyPredicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("  hp    >    target.hp  ")
        XCTAssertEqual(try bodyPredicate(context(body.id), rpSpace), true)
        XCTAssertEqual(try bodyPredicate(context(enemy.id), rpSpace), false)

        let hpValuePredicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("hp == 40")
        XCTAssertEqual(try hpValuePredicate(context(body.id), rpSpace), true)
        XCTAssertEqual(try hpValuePredicate(context(enemy.id), rpSpace), false)

        let hpGreaterThanPredicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("hp > 30")
        XCTAssertEqual(try hpGreaterThanPredicate(context(body.id), rpSpace), true)
        XCTAssertEqual(try hpGreaterThanPredicate(context(enemy.id), rpSpace), false)

        rpSpace.modifyBody(id: body.id) { modBody, _ in
            modBody.setCurrentStats(.init(dict: [\.hp: 10]))
        }
        XCTAssertEqual(try hpGreaterThanPredicate(context(body.id), rpSpace), false)

        let hpPercentagePredicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("hp% > 10%")
        XCTAssertEqual(try hpPercentagePredicate(context(body.id), rpSpace), true)

        let malformedPredicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("hp > 10%")
        XCTAssertThrowsError(try malformedPredicate(context(body.id), rpSpace)) { error in
            XCTAssertEqual(error is ConditionalInterpretationError, true)
        }
    }

    func testConjunctionPredicate() throws {
        var body = RPBody<TestRPSpace>(["hp": 40])
        let enemy = RPBody<TestRPSpace>(["hp": 20])
        body.addThreat(toward: enemy.id, amount: 1)

        rpSpace.addBody(body)
        rpSpace.addBody(enemy)

        let predicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("hp > 30 && hp > target.hp")
        XCTAssertEqual(try predicate(context(body.id), rpSpace), true)
        XCTAssertEqual(try predicate(context(enemy.id), rpSpace), false)
    }

    func testDisjunctionPredicate() throws {
        var body = RPBody<TestRPSpace>(["hp": 40])
        let enemy = RPBody<TestRPSpace>(["hp": 20])

        rpSpace.addBody(body)
        rpSpace.addBody(enemy)

        let predicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("hp > 30 || hp == 20")
        XCTAssertEqual(try predicate(context(body.id), rpSpace), true)
        XCTAssertEqual(try predicate(context(enemy.id), rpSpace), true)

        let bothSidesFalse: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("hp > 100 || hp < 5")
        XCTAssertEqual(try bothSidesFalse(context(body.id), rpSpace), false)
    }

    func testNeitherNorIsExpressedByInvertingEachClause() throws {
        var body = RPBody<TestRPSpace>(["hp": 40])
        let enemy = RPBody<TestRPSpace>(["hp": 20])

        rpSpace.addBody(body)
        rpSpace.addBody(enemy)

        let neitherTooHighNorTooLow: RPConditional<TestRPSpace>.Predicate =
            try interpretStringCondition("hp <= 100 && hp >= 30")
        XCTAssertEqual(try neitherTooHighNorTooLow(context(body.id), rpSpace), true)
        XCTAssertEqual(try neitherTooHighNorTooLow(context(enemy.id), rpSpace), false)

        let neitherHealingNorDieing: RPConditional<TestRPSpace>.Predicate =
            try interpretStringCondition("!statusAny(Healing) && !statusAny(Dieing)")
        XCTAssertEqual(try neitherHealingNorDieing(context(body.id), rpSpace), true)
    }

    func testStatsAndLogicStatusEffectExistence() throws {
        var body = RPBody<TestRPSpace>(["hp": 40])
        let enemy = RPBody<TestRPSpace>(["hp": 20])

        rpSpace.addBody(body)
        rpSpace.addBody(enemy)

        let healingQuery: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("   statusAny(Healing)   ")
        let healingQuery2: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("  !  statusAny( Healing )  ")
        let dyingQuery: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("   statusAny(Dieing)   ")
        let dyingQuery2: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("  !statusAny(Dieing)  ")

        let statusEffect = RPStatusEffect<TestRPSpace>(
            code: "Healing",
            tags: ["Healing"],
            duration: 1,
            charges: 0
        )

        rpSpace.modifyBody(id: body.id) { e, _ in e.applyStatusEffect(statusEffect) }

        XCTAssertEqual(try healingQuery(context(body.id), rpSpace), true)
        XCTAssertEqual(try healingQuery2(context(body.id), rpSpace), false)
        XCTAssertEqual(try dyingQuery(context(body.id), rpSpace), false)
        XCTAssertEqual(try dyingQuery2(context(body.id), rpSpace), true)
    }

    func testUsesQueriesExecutableAbilityTags() throws {
        var caster = RPBody<TestRPSpace>(["hp": 40])
        caster.addExecutableAbility(
            RPAbility<TestRPSpace>(code: "Zap", tags: [RPAbilityTag("magical")]),
            conditional: .always
        )
        rpSpace.addBody(caster)

        let predicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("usesAny(magical)")
        XCTAssertEqual(try predicate(context(caster.id), rpSpace), true)
        XCTAssertEqual(try predicate(context(enemy.id), rpSpace), false)
    }

    func testHoldsQueriesInventoryItemTags() throws {
        var carrier = RPBody<TestRPSpace>(["hp": 40])
        carrier.inventory.append(
            RPActiveItem(item: RPItem<TestRPSpace>(code: "gold-key", tags: [RPItemTag("key")]))
        )
        rpSpace.addBody(carrier)

        let predicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("holdsAny(key)")
        XCTAssertEqual(try predicate(context(carrier.id), rpSpace), true)
        XCTAssertEqual(try predicate(context(enemy.id), rpSpace), false)

        let negated: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("!holdsAny(key)")
        XCTAssertEqual(try negated(context(carrier.id), rpSpace), false)
        XCTAssertEqual(try negated(context(enemy.id), rpSpace), true)
    }

    func testHoldsQueriesWornItemTags() throws {
        var wearer = RPBody<TestRPSpace>(["hp": 40])
        wearer.equipment.equip(
            RPActiveItem(
                item: RPItem<TestRPSpace>(
                    code: "iron-shield",
                    tags: [RPItemTag("shield")],
                    equipmentSlotCode: RPEquipmentSlotCode("offhand")
                )
            )
        )
        rpSpace.addBody(wearer)

        let predicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("holdsAny(shield)")
        XCTAssertEqual(try predicate(context(wearer.id), rpSpace), true)
    }

    func testAnyMatchesOneOfManyAndAllRequiresEveryTag() throws {
        var carrier = RPBody<TestRPSpace>(["hp": 40])
        carrier.inventory.append(
            RPActiveItem(item: RPItem<TestRPSpace>(code: "fire-orb", tags: [RPItemTag("magic.fire")]))
        )
        rpSpace.addBody(carrier)

        let anyQuery: RPConditional<TestRPSpace>.Predicate =
            try interpretStringCondition("holdsAny(magic.fire, magic.ice)")
        XCTAssertEqual(try anyQuery(context(carrier.id), rpSpace), true)

        let allQuery: RPConditional<TestRPSpace>.Predicate =
            try interpretStringCondition("holds(magic.fire, magic.ice)")
        XCTAssertEqual(try allQuery(context(carrier.id), rpSpace), false)

        let negatedAll: RPConditional<TestRPSpace>.Predicate =
            try interpretStringCondition("!holds(magic.fire, magic.ice)")
        XCTAssertEqual(try negatedAll(context(carrier.id), rpSpace), true)

        rpSpace.modifyBody(id: carrier.id) { e, _ in
            e.inventory.append(
                RPActiveItem(item: RPItem<TestRPSpace>(code: "ice-orb", tags: [RPItemTag("magic.ice")]))
            )
        }
        XCTAssertEqual(try allQuery(context(carrier.id), rpSpace), true)
        XCTAssertEqual(try negatedAll(context(carrier.id), rpSpace), false)
    }

    func testTagQueriesFollowTheTargetChain() throws {
        let statusEffect = RPStatusEffect<TestRPSpace>(
            code: "Healing",
            tags: ["Healing"],
            duration: 1,
            charges: 0
        )
        rpSpace.modifyBody(id: enemy.id) { e, _ in e.applyStatusEffect(statusEffect) }

        let predicate: RPConditional<TestRPSpace>.Predicate =
            try interpretStringCondition("target.statusAny(Healing)")
        XCTAssertEqual(try predicate(context(body.id), rpSpace), true)

        let allQuery: RPConditional<TestRPSpace>.Predicate =
            try interpretStringCondition("target.status(Healing, Dieing)")
        XCTAssertEqual(try allQuery(context(body.id), rpSpace), false)
    }
}

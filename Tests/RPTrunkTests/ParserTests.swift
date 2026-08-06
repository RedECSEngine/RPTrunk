@testable import RPTrunk
import XCTest

final class ParserTests: XCTestCase {
    var body: RPBody<TestRPSpace>!
    var enemy: RPBody<TestRPSpace>!
    var rpSpace: TestRPSpace!

    override func setUp() {
        body = RPBody(["hp": 30])
        enemy = RPBody(["hp": 30])
        body.targets = [enemy!.id]
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
        XCTAssertEqual(try ConditionTokenParser.classify("has"), .has)
        XCTAssertEqual(try ConditionTokenParser.classify("uses"), .uses)
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
        let parsed = try parseCondition("hp > 10 && !has.Healing")
        XCTAssertEqual(parsed.orGroups.count, 1)
        XCTAssertEqual(parsed.orGroups[0].count, 2)
        XCTAssertEqual(parsed.orGroups[0][0].comparison?.op, .greaterThan)
        XCTAssertEqual(parsed.orGroups[0][1].lhs.tokens, [.has, .keyword("Healing", usePercent: false)])
        XCTAssertNil(parsed.orGroups[0][1].comparison)
        XCTAssertTrue(parsed.orGroups[0][1].isNegated)
    }

    func testDisjunctionParsingAndPrecedence() throws {
        XCTAssertEqual(
            try printCondition(parseCondition("hp < 5||has.Healing && hp > 2")),
            "hp < 5 || has.Healing && hp > 2"
        )
        let parsed = try parseCondition("hp < 5 || has.Healing && hp > 2")
        XCTAssertEqual(parsed.orGroups.count, 2)
        XCTAssertEqual(parsed.orGroups[0].count, 1)
        XCTAssertEqual(parsed.orGroups[1].count, 2)
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

    // MARK: - Printing

    func testPrintingIsCanonical() throws {
        XCTAssertEqual(try printCondition(parseCondition("  hp    >    target.hp  ")), "hp > target.hp")
        XCTAssertEqual(try printCondition(parseCondition("hp% > 10%")), "hp% > 10%")
        XCTAssertEqual(try printCondition(parseCondition("  has.Healing  ")), "has.Healing")
        XCTAssertEqual(
            try printCondition(parseCondition("hp > 10&&!has.Healing")),
            "hp > 10 && !has.Healing"
        )
    }

    func testPrintedConditionRoundTrips() throws {
        let conditions = [
            "hp > target.hp",
            "hp% > 10%",
            "hp == 40",
            "!has.Healing",
            "has.Dieing",
            "hp > 10 && !has.Healing",
            "hp < 5 || has.Healing && hp > 2",
            "hp >= 5 && hp <= 100",
            "!has.Healing && !has.Dieing",
            "target.hp < 5",
            "self.hp% < hp%",
            "has.bleed",
            "uses.magical",
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

    func testStatusQueriesRequireTheHasPrefix() {
        assertCompileFails("bleed", with: .invalidSyntax(reason: "Unknown stat: bleed"))
        assertCompileFails("!bleed", with: .invalidSyntax(reason: "Unknown stat: bleed"))
        assertCompileFails(
            "has",
            with: .invalidSyntax(reason: "`has.` must be followed by a status tag, e.g. `has.bleed`")
        )
        assertCompileFails(
            "hp",
            with: .invalidSyntax(reason: "A clause without an operator must be a `has.` or `uses.` tag query")
        )
    }

    func testNegationOnlyAppliesToTagQueries() {
        assertCompileFails(
            "!hp > 5",
            with: .invalidSyntax(reason: "`!` negates a `has.` or `uses.` tag query, not a comparison")
        )
        XCTAssertNoThrow(
            try interpretStringCondition("!uses.magical") as RPConditional<TestRPSpace>.Predicate
        )
    }

    func testPrefixesMustPairWithATagQuery() {
        let hasPairing = ConditionalInterpretationError.invalidSyntax(
            reason: "`has.` must be followed by a status tag, e.g. `has.bleed`"
        )
        assertCompileFails("has.hp% > 1", with: hasPairing)
        assertCompileFails("has.40 > 1", with: hasPairing)
        assertCompileFails(
            "uses.hp% > 1",
            with: .invalidSyntax(reason: "`uses.` must be followed by an ability tag, e.g. `uses.magical`")
        )
    }

    func testStatsAndLogicCanReadSelfAndTargetHP() {
        var body = RPBody<TestRPSpace>(["hp": 40])
        let enemy = RPBody<TestRPSpace>(["hp": 20])
        body.targets = [enemy.id]

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
        body.targets = [enemy.id]

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
        body.targets = [enemy.id]
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
        body.targets = [enemy.id]

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
        body.targets = [enemy.id]

        rpSpace.addBody(body)
        rpSpace.addBody(enemy)

        let predicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("hp > 30 && hp > target.hp")
        XCTAssertEqual(try predicate(context(body.id), rpSpace), true)
        XCTAssertEqual(try predicate(context(enemy.id), rpSpace), false)
    }

    func testDisjunctionPredicate() throws {
        var body = RPBody<TestRPSpace>(["hp": 40])
        let enemy = RPBody<TestRPSpace>(["hp": 20])
        body.targets = [enemy.id]

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
        body.targets = [enemy.id]

        rpSpace.addBody(body)
        rpSpace.addBody(enemy)

        let neitherTooHighNorTooLow: RPConditional<TestRPSpace>.Predicate =
            try interpretStringCondition("hp <= 100 && hp >= 30")
        XCTAssertEqual(try neitherTooHighNorTooLow(context(body.id), rpSpace), true)
        XCTAssertEqual(try neitherTooHighNorTooLow(context(enemy.id), rpSpace), false)

        let neitherHealingNorDieing: RPConditional<TestRPSpace>.Predicate =
            try interpretStringCondition("!has.Healing && !has.Dieing")
        XCTAssertEqual(try neitherHealingNorDieing(context(body.id), rpSpace), true)
    }

    func testStatsAndLogicStatusEffectExistence() throws {
        var body = RPBody<TestRPSpace>(["hp": 40])
        let enemy = RPBody<TestRPSpace>(["hp": 20])
        body.targets = [enemy.id]

        rpSpace.addBody(body)
        rpSpace.addBody(enemy)

        let healingQuery: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("   has.Healing   ")
        let healingQuery2: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("  !  has.Healing  ")
        let dyingQuery: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("   has.Dieing   ")
        let dyingQuery2: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("  !has.Dieing  ")

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

    func testUsesPrefixQueriesExecutableAbilityTags() throws {
        var caster = RPBody<TestRPSpace>(["hp": 40])
        caster.addExecutableAbility(
            RPAbility<TestRPSpace>(code: "Zap", tags: [RPAbilityTag("magical")]),
            conditional: .always
        )
        rpSpace.addBody(caster)

        let predicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("uses.magical")
        XCTAssertEqual(try predicate(context(caster.id), rpSpace), true)
        XCTAssertEqual(try predicate(context(enemy.id), rpSpace), false)
    }
}

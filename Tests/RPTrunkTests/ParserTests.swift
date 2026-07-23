@testable import RPTrunk
import XCTest

final class ParserTests: XCTestCase {
    var entity: RPEntity<TestRPSpace>!
    var enemy: RPEntity<TestRPSpace>!
    var rpSpace: TestRPSpace!

    override func setUp() {
        entity = RPEntity(["hp": 30])
        enemy = RPEntity(["hp": 30])
        entity.targets = [enemy!.id]
        rpSpace = TestRPSpace()

        var entityTeam = RPTeam<TestRPSpace>()
        entityTeam.add(&entity)
        var enemyTeam = RPTeam<TestRPSpace>()
        enemyTeam.add(&enemy)

        rpSpace.addEntity(entity)
        rpSpace.addEntity(enemy)
        rpSpace.setTeams([entityTeam, enemyTeam])
    }

    // MARK: - Syntax

    func testTokenClassification() throws {
        XCTAssertEqual(try ConditionTokenParser.classify("target"), .target)
        XCTAssertEqual(try ConditionTokenParser.classify("hp"), .identifier("hp", usePercent: false))
        XCTAssertEqual(try ConditionTokenParser.classify("hp%"), .identifier("hp", usePercent: true))
        XCTAssertEqual(try ConditionTokenParser.classify("Healing?"), .status("Healing"))
        XCTAssertEqual(try ConditionTokenParser.classify("40"), .value(40))
        XCTAssertEqual(try ConditionTokenParser.classify("10%"), .percent(10))
        XCTAssertEqual(try ConditionTokenParser.classify("true"), .bool(true))
        XCTAssertEqual(try ConditionTokenParser.classify("false"), .bool(false))
    }

    func testDotNotationChainParsing() throws {
        let parsed = try parseCondition("target.hp == target.hp")
        XCTAssertEqual(parsed.clauses.count, 1)

        let clause = parsed.clauses[0]
        XCTAssertEqual(clause.lhs.tokens, [.target, .identifier("hp", usePercent: false)])
        XCTAssertEqual(clause.comparison?.op, .Equal)
        XCTAssertEqual(clause.comparison?.rhs.tokens, [.target, .identifier("hp", usePercent: false)])
    }

    func testWhitespaceTolerance() throws {
        let parsed = try parseCondition("  hp    >    target.hp  ")
        XCTAssertEqual(
            parsed,
            ParsedCondition(clauses: [
                ConditionClause(
                    lhs: .init(tokens: [.identifier("hp", usePercent: false)]),
                    comparison: .init(op: .GreaterThan, rhs: .init(tokens: [.target, .identifier("hp", usePercent: false)]))
                ),
            ])
        )
    }

    func testConjunctionParsing() throws {
        let parsed = try parseCondition("hp > 10 && Healing? == false")
        XCTAssertEqual(parsed.clauses.count, 2)
        XCTAssertEqual(parsed.clauses[0].comparison?.op, .GreaterThan)
        XCTAssertEqual(parsed.clauses[1].lhs.tokens, [.status("Healing")])
        XCTAssertEqual(parsed.clauses[1].comparison?.rhs.tokens, [.bool(false)])
    }

    func testOperatorParsing() throws {
        XCTAssertEqual(try parseCondition("hp > 1").clauses[0].comparison?.op, .GreaterThan)
        XCTAssertEqual(try parseCondition("hp < 1").clauses[0].comparison?.op, .LessThan)
        XCTAssertEqual(try parseCondition("hp == 1").clauses[0].comparison?.op, .Equal)
        XCTAssertEqual(try parseCondition("hp != 1").clauses[0].comparison?.op, .NotEqual)
    }

    func testUnparseableConditionsThrow() {
        XCTAssertThrowsError(try parseCondition(""))
        XCTAssertThrowsError(try parseCondition("hp >"))
        XCTAssertThrowsError(try parseCondition("hp > 10 &&"))
        XCTAssertThrowsError(try parseCondition("hp ~ 10"))
    }

    // MARK: - Printing

    func testPrintingIsCanonical() throws {
        XCTAssertEqual(try printCondition(parseCondition("  hp    >    target.hp  ")), "hp > target.hp")
        XCTAssertEqual(try printCondition(parseCondition("hp% > 10%")), "hp% > 10%")
        XCTAssertEqual(try printCondition(parseCondition("  Healing?  ")), "Healing?")
        XCTAssertEqual(
            try printCondition(parseCondition("hp > 10&&Healing? == false")),
            "hp > 10 && Healing? == false"
        )
    }

    func testPrintedConditionRoundTrips() throws {
        let conditions = [
            "hp > target.hp",
            "hp% > 10%",
            "hp == 40",
            "Healing? == false",
            "Dieing?",
            "hp > 10 && Healing? == false",
            "target.hp < 5",
        ]
        for condition in conditions {
            let parsed = try parseCondition(condition)
            let printed = try printCondition(parsed)
            XCTAssertEqual(printed, condition, "canonical form should be stable")
            XCTAssertEqual(try parseCondition(printed), parsed, "print → parse should round-trip")
        }
    }

    // MARK: - Compilation + evaluation

    func testShouldReturnEntityTarget() throws {
        let evaluators: [ParserResultType<TestRPSpace>] = try compileOperand(.init(tokens: [.target]))

        guard case let .evaluationFunction(f) = evaluators[0] else {
            XCTFail()
            return
        }

        let result = f(.entityResult(entity: entity.id), rpSpace)

        if case let .entityResult(e) = result {
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

        let result = f(.entityResult(entity: enemy.id), rpSpace)
        switch result {
        case .nothing:
            break
        default:
            XCTFail()
        }
    }

    func testUnknownStatFailsCompilation() {
        XCTAssertThrowsError(
            try interpretStringCondition("wisdom > 10") as RPConditional<TestRPSpace>.Predicate
        ) { error in
            XCTAssertEqual(error is ConditionalInterpretationError, true)
        }
    }

    func testStatsAndLogicCanReadSelfAndTargetHP() {
        var entity = RPEntity<TestRPSpace>(["hp": 40])
        let enemy = RPEntity<TestRPSpace>(["hp": 20])
        entity.targets = [enemy.id]

        rpSpace.addEntity(entity)
        rpSpace.addEntity(enemy)

        let result = extractValue(entity.id, evaluate: "hp", in: rpSpace)
        XCTAssertEqual(result, .rpValue(40))

        let result2 = extractValue(entity.id, evaluate: "target.hp", in: rpSpace)
        XCTAssertEqual(result2, .rpValue(20))
    }

    func testStatsAndLogicComparison() throws {
        var entity = RPEntity<TestRPSpace>(["hp": 40])
        let enemy = RPEntity<TestRPSpace>(["hp": 20])
        entity.targets = [enemy.id]

        rpSpace.addEntity(entity)
        rpSpace.addEntity(enemy)

        let entityPredicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("  hp    >    target.hp  ")
        XCTAssertEqual(try entityPredicate(entity.id, rpSpace), true)
        XCTAssertEqual(try entityPredicate(enemy.id, rpSpace), false)

        let hpValuePredicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("hp == 40")
        XCTAssertEqual(try hpValuePredicate(entity.id, rpSpace), true)
        XCTAssertEqual(try hpValuePredicate(enemy.id, rpSpace), false)

        let hpGreaterThanPredicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("hp > 30")
        XCTAssertEqual(try hpGreaterThanPredicate(entity.id, rpSpace), true)
        XCTAssertEqual(try hpGreaterThanPredicate(enemy.id, rpSpace), false)

        rpSpace.modifyEntity(id: entity.id) { modEntity, _ in
            modEntity.currentStats.hp = 10
        }
        XCTAssertEqual(try hpGreaterThanPredicate(entity.id, rpSpace), false)

        let hpPercentagePredicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("hp% > 10%")
        XCTAssertEqual(try hpPercentagePredicate(entity.id, rpSpace), true)

        let malformedPredicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("hp > 10%")
        XCTAssertThrowsError(try malformedPredicate(entity.id, rpSpace)) { error in
            XCTAssertEqual(error is ConditionalInterpretationError, true)
        }
    }

    func testConjunctionPredicate() throws {
        var entity = RPEntity<TestRPSpace>(["hp": 40])
        let enemy = RPEntity<TestRPSpace>(["hp": 20])
        entity.targets = [enemy.id]

        rpSpace.addEntity(entity)
        rpSpace.addEntity(enemy)

        let predicate: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("hp > 30 && hp > target.hp")
        XCTAssertEqual(try predicate(entity.id, rpSpace), true)
        XCTAssertEqual(try predicate(enemy.id, rpSpace), false)
    }

    func testStatsAndLogicStatusEffectExistence() throws {
        var entity = RPEntity<TestRPSpace>(["hp": 40])
        let enemy = RPEntity<TestRPSpace>(["hp": 20])
        entity.targets = [enemy.id]

        rpSpace.addEntity(entity)
        rpSpace.addEntity(enemy)

        let healingQuery: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("   Healing?   ")
        let healingQuery2: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("   Healing?   ==   false  ")
        let dyingQuery: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("   Dieing?   ")
        let dyingQuery2: RPConditional<TestRPSpace>.Predicate = try interpretStringCondition("   Dieing?    ==   false  ")

        let statusEffect = RPStatusEffect<TestRPSpace>(
            code: "Healing",
            tags: [],
            fragments: [],
            duration: 1,
            charges: 0
        )

        rpSpace.modifyEntity(id: entity.id) { e, _ in e.applyStatusEffect(statusEffect) }

        XCTAssertEqual(try healingQuery(entity.id, rpSpace), true)
        XCTAssertEqual(try healingQuery2(entity.id, rpSpace), false)
        XCTAssertEqual(try dyingQuery(entity.id, rpSpace), false)
        XCTAssertEqual(try dyingQuery2(entity.id, rpSpace), true)
    }
}

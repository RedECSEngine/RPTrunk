@testable import RPTrunk
import XCTest

final class ParserTests: XCTestCase {
    static var allTests = [
        ("testShouldReturnEntityTarget", testShouldReturnEntityTarget),
    ]

    var entity: Entity!
    var enemy: Entity!
    var rpSpace: RPSpace!

    override func setUp() {
        let env = RPGameEnvironment(delegate: DefaultGame())
        RPGameEnvironment.pushEnvironment(env)

        entity = Entity()
        enemy = Entity()
        entity.targets = [enemy]
    }

    func testShouldReturnEntityTarget() {
        let result = targetParser.parse("target")

        guard case let .evaluationFunction(f) = result else {
            XCTFail()
            return
        }

        let result2 = f(.entityResult(entity: entity))

        if case let .entityResult(e) = result2 {
            XCTAssertEqual(e === enemy, true)
        } else {
            XCTFail()
        }
    }

    func testGetNothingWhenTargetIsNil() {
        let result = targetParser.parse("target")

        guard case let .evaluationFunction(f) = result else {
            XCTFail()
            return
        }

        let result2 = f(.entityResult(entity: enemy))
        switch result2 {
        case .nothing:
            break
        default:
            XCTFail()
        }
    }
    
    func testGetStatReaderResult() {
        let enemy = Entity(["hp": 20])
        
        let result = statParser.parse("hp")

        guard case let .evaluationFunction(f) = result else {
            XCTFail()
            return
        }

        let result2 = f(.entityResult(entity: enemy))
        switch result2 {
        case .valueResult(value: let value):
            XCTAssertEqual(value, .rpValue(20))
        default:
            XCTFail()
        }
    }

    func testStatsAndLogicCanReadSelfAndTargetHP() {
        let entity = Entity(["hp": 40])
        let enemy = Entity(["hp": 20])
        entity.targets = [enemy]
        
        let result = extractValue(entity, evaluate: "hp")
        XCTAssertEqual(result, .rpValue(40))

        let result2 = extractValue(entity, evaluate: "target.hp")
        XCTAssertEqual(result2, .rpValue(20))
    }
    
    func testLogicOperatorParser() {
        XCTAssertEqual(logicalOperatorParser.parse("  > "), .GreaterThan)
        XCTAssertEqual(logicalOperatorParser.parse("  < "), .LessThan)
        XCTAssertEqual(logicalOperatorParser.parse(" == "), .Equal)
        XCTAssertEqual(logicalOperatorParser.parse(" != "), .NotEqual)
    }
    
    func testLogicComparisonParser() {
        guard let (lhs, op, rhs) = logicalComparisonParser.parse("target.hp == target.hp") else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(lhs.count, 2)
        guard case .evaluationFunction = lhs.first,
              case .evaluationFunction = lhs.last else {
            XCTFail()
            return
        }
        XCTAssertEqual(op, .Equal)
        guard case .evaluationFunction = rhs.first,
              case .evaluationFunction = rhs.last else {
            XCTFail()
            return
        }
        XCTAssertEqual(rhs.count, 2)
    }

    func testStatsAndLogicComparison() throws {
        let entity = Entity(["hp": 40])
        let enemy = Entity(["hp": 20])
        entity.targets = [enemy]

        let entityPredicate = try interpretStringCondition("  hp    >    target.hp  ")
        XCTAssertEqual(try entityPredicate(entity), true)
        XCTAssertEqual(try entityPredicate(enemy), false)
        
        let hpValuePredicate = try interpretStringCondition("hp == 40")
        XCTAssertEqual(try hpValuePredicate(entity), true)
        XCTAssertEqual(try hpValuePredicate(enemy), false)
        
        let hpGreaterThanPredicate = try interpretStringCondition("hp > 30")
        XCTAssertEqual(try hpGreaterThanPredicate(entity), true)
        XCTAssertEqual(try hpGreaterThanPredicate(enemy), false)
        
        entity.setCurrentStats(["hp": 10])
        XCTAssertEqual(try hpGreaterThanPredicate(entity), false)
        
        let hpPercentagePredicate = try interpretStringCondition("hp% > 10%")
        XCTAssertEqual(try hpPercentagePredicate(entity), true)
        
        let malformedPredicate = try interpretStringCondition("hp > 10%")
        XCTAssertThrowsError(try malformedPredicate(entity)) { error in
            XCTAssertEqual(error is ConditionalInterpretationError, true)
        }
    }
    

    func testStatsAndLogicStatusEffectExistence() throws {
        let entity = Entity(["hp": 40])
        let enemy = Entity(["hp": 20])
        entity.targets = [enemy]

        let healingQuery = try interpretStringCondition("   Healing?   ")
        let healingQuery2 = try interpretStringCondition("   Healing?   ==   false  ")
        let dyingQuery = try interpretStringCondition("   Dieing?   ")
        let dyingQuery2 = try interpretStringCondition("   Dieing?    ==   false  ")

        let statusEffect = StatusEffect(
            name: "Healing",
            labels: [],
            components: [],
            duration: 1,
            charges: 0
        )
        entity.applyStatusEffect(statusEffect)

        XCTAssertEqual(try healingQuery(entity), true)
        XCTAssertEqual(try healingQuery2(entity), false)
        XCTAssertEqual(try dyingQuery(entity), false)
        XCTAssertEqual(try dyingQuery2(entity), true)
    }
}

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
        entity.targets = [enemy!.id]
        
        rpSpace = RPSpace()
        rpSpace.addEntity(entity)
        rpSpace.addEntity(enemy)
    }

    func testShouldReturnEntityTarget() {
        let result = targetParser.parse("target")

        guard case let .evaluationFunction(f) = result else {
            XCTFail()
            return
        }

        let result2 = f(.entityResult(entity: entity.id), rpSpace)

        if case let .entityResult(e) = result2 {
            XCTAssertEqual(e == enemy.id, true)
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

        let result2 = f(.entityResult(entity: enemy.id), rpSpace)
        switch result2 {
        case .nothing:
            break
        default:
            XCTFail()
        }
    }
    
    func testGetStatReaderResult() {
        let enemy = Entity(["hp": 20])
        rpSpace.addEntity(enemy)
        
        let result = statParser.parse("hp")

        guard case let .evaluationFunction(f) = result else {
            XCTFail()
            return
        }

        let result2 = f(.entityResult(entity: enemy.id), rpSpace)
        switch result2 {
        case .valueResult(value: let value):
            XCTAssertEqual(value, .rpValue(20))
        default:
            XCTFail()
        }
    }

    func testStatsAndLogicCanReadSelfAndTargetHP() {
        var entity = Entity(["hp": 40])
        let enemy = Entity(["hp": 20])
        entity.targets = [enemy.id]
        
        rpSpace.addEntity(entity)
        rpSpace.addEntity(enemy)
        
        let result = extractValue(entity.id, evaluate: "hp", in: rpSpace)
        XCTAssertEqual(result, .rpValue(40))

        let result2 = extractValue(entity.id, evaluate: "target.hp", in: rpSpace)
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
        var entity = Entity(["hp": 40])
        let enemy = Entity(["hp": 20])
        entity.targets = [enemy.id]
        
        rpSpace.addEntity(entity)
        rpSpace.addEntity(enemy)

        let entityPredicate = try interpretStringCondition("  hp    >    target.hp  ")
        XCTAssertEqual(try entityPredicate(entity.id, rpSpace), true)
        XCTAssertEqual(try entityPredicate(enemy.id, rpSpace), false)
        
        let hpValuePredicate = try interpretStringCondition("hp == 40")
        XCTAssertEqual(try hpValuePredicate(entity.id, rpSpace), true)
        XCTAssertEqual(try hpValuePredicate(enemy.id, rpSpace), false)
        
        let hpGreaterThanPredicate = try interpretStringCondition("hp > 30")
        XCTAssertEqual(try hpGreaterThanPredicate(entity.id, rpSpace), true)
        XCTAssertEqual(try hpGreaterThanPredicate(enemy.id, rpSpace), false)
        
        rpSpace.modifyEntity(id: entity.id) { modEntity in
            modEntity.setCurrentStats(["hp": 10])
        }
        XCTAssertEqual(try hpGreaterThanPredicate(entity.id, rpSpace), false)
        
        let hpPercentagePredicate = try interpretStringCondition("hp% > 10%")
        XCTAssertEqual(try hpPercentagePredicate(entity.id, rpSpace), true)
        
        let malformedPredicate = try interpretStringCondition("hp > 10%")
        XCTAssertThrowsError(try malformedPredicate(entity.id, rpSpace)) { error in
            XCTAssertEqual(error is ConditionalInterpretationError, true)
        }
    }
    

    func testStatsAndLogicStatusEffectExistence() throws {
        var entity = Entity(["hp": 40])
        let enemy = Entity(["hp": 20])
        entity.targets = [enemy.id]
        
        rpSpace.addEntity(entity)
        rpSpace.addEntity(enemy)

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

        rpSpace.modifyEntity(id: entity.id) { $0.applyStatusEffect(statusEffect) }

        XCTAssertEqual(try healingQuery(entity.id, rpSpace), true)
        XCTAssertEqual(try healingQuery2(entity.id, rpSpace), false)
        XCTAssertEqual(try dyingQuery(entity.id, rpSpace), false)
        XCTAssertEqual(try dyingQuery2(entity.id, rpSpace), true)
    }
}

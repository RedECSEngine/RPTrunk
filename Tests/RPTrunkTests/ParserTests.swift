import XCTest
@testable import RPTrunk

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
        let query: ArraySlice<String> = ArraySlice(["target"])
        
        let parser = targetParser()
        let result = parser.p(query).makeIterator().next()
        
        guard case let .evaluationFunction(f) = result!.0 else {
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
        let query: ArraySlice<String> = ArraySlice(["target"])
        let parser = targetParser()
        let result = parser.p(query).makeIterator().next()
        
        guard case let .evaluationFunction(f) = result!.0 else {
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
    
    func testStatsAndLogicCanReadSelfAndTargetHP() {
        let entity = Entity(["hp": 40])
        let enemy = Entity(["hp": 20])
        entity.targets = [enemy]
        
        let result = extractResult(entity, evaluators: parse(ArraySlice(["hp"])) )
        XCTAssertEqual(result, 40)
        
        let result2 = extractResult(entity, evaluators: parse(ArraySlice(["target", "hp"])) )
        XCTAssertEqual(result2, 20)
    }
    
    func testStatsAndLogicComparison() {
        let entity = Entity(["hp": 40])
        let enemy = Entity(["hp": 20])
        entity.targets = [enemy]
        
        let entityPredicate = try! interpretStringCondition("hp > target.hp")
        XCTAssertEqual(entityPredicate(entity), true)
        XCTAssertEqual(entityPredicate(enemy), false)
    }
    
    func testStatsAndLogicStatusEffectExistence() {
        let entity = Entity(["hp": 40])
        let enemy = Entity(["hp": 20])
        entity.targets = [enemy]
        
        let healingQuery = try! interpretStringCondition("Healing?")
        let dieingQuery = try! interpretStringCondition("Dieing?")
        
        let statusEffect = StatusEffect(identity: "Healing", components: [], duration: 1, charges: 0)
        entity.applyStatusEffect(statusEffect)
        
        XCTAssertEqual(healingQuery(entity), true)
        XCTAssertEqual(dieingQuery(entity), false)
    }
 
}

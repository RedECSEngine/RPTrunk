import Quick
import Nimble

@testable import RPTrunk

class ParserSpec: QuickSpec {
    
    enum TestError:Error {
        case invalidCase
    }
    
    override func spec() {
        
        describe("Parser") {
            
            let env = RPGameEnvironment(delegate: DefaultGame())
            RPGameEnvironment.pushEnvironment(env)
            
            let entity = Entity()
            let enemy = Entity()
            entity.targets = [enemy]
            
            context("getTarget") {
                
                let query:ArraySlice<String> = ArraySlice(["target"])
                
                it("should return the entity's target") {
                    
                    let parser = targetParser()
                    let result = parser.p(query).makeIterator().next()
                    
                    guard case let .evaluationFunction(f) = result!.0 else {
                        
                        expect(false).to(beTrue())
                        return
                    }
                    
                    let result2 = f(.entityResult(entity:entity))
                    
                    if case let .entityResult(e) = result2 {
                        
                        expect(e === enemy).to(beTrue())
                    } else {
                        
                        expect(false).to(beTrue())
                    }
                    
                }
                
                it("should return .Nothing when the enemy's target is nil") {
                    
                    let parser = targetParser()
                    let result = parser.p(query).makeIterator().next()
                    
                    guard case let .evaluationFunction(f) = result!.0 else {
                        
                        expect(false).to(beTrue())
                        return
                    }
                    
                    let result2 = f(.entityResult(entity:enemy))
                    
                    switch result2 {
                    case .nothing:
                        break
                    default:
                        
                        expect(false).to(beTrue())
                    }
                }
                
            }
            
            context("Stats and logic") {
            
                let entity = Entity(["hp": 40])
                let enemy = Entity(["hp": 20])
                entity.targets = [enemy]
                
                
                it("should be able to read the hp it both the entity and its target") {
                    let result = extractResult(entity, evaluators: parse(ArraySlice(["hp"])) )
                    expect(result).to(equal(40))
                    
                    let result2 = extractResult(entity, evaluators: parse(ArraySlice(["target", "hp"])) )
                    expect(result2).to(equal(20))
                }
                
                it("should be able to compare stats between entities through the parser"){
                    let entityPredicate = try! interpretStringCondition("hp > target.hp")
                    
                    expect(entityPredicate(entity)).to(equal(true))
                    expect(entityPredicate(enemy)).to(equal(false))
                }
                
                it("should be able to read for status effects"){
                    let healingQuery = try! interpretStringCondition("Healing?")
                    let dieingQuery = try! interpretStringCondition("Dieing?")
                    
                    let statusEffect = StatusEffect(identity: "Healing", components: [], duration: 1, charges: 0)
                    entity.applyStatusEffect(statusEffect)
                    
                    expect(healingQuery(entity)).to(equal(true))
                    expect(dieingQuery(entity)).to(equal(false))
                }
            }
            
        }
    }
}

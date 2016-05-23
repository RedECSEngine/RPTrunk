import Quick
import Nimble

@testable import RPTrunk

class ParserSpec: QuickSpec {
    
    enum Error:ErrorType {
        case InvalidCase
    }
    
    override func spec() {
        
        describe("Parser") {
            
            let env = RPGameEnvironment(delegate: DefaultGame())
            RPGameEnvironment.pushEnvironment(env)
            
            let entity = Entity()
            let enemy = Entity()
            entity.target = enemy
            
            context("getTarget") {
                
                let query:ArraySlice<String> = ArraySlice(["target"])
                
                it("should return the entity's target") {
                    
                    let parser = entityTargetParser(entity)
                    let result = parser.p(query).generate().next()
                    
                    switch result!.0 {
                    case .EntityResult(let e):
                        
                        expect(e === enemy).to(beTrue())
                    default:
                        expect(false).to(beTrue())
                    }
                    
                }
                
                it("should return .Nothing when the enemy's target is nil") {
                    
                    let parser = entityTargetParser(enemy)
                    let result = parser.p(query).generate().next()
                    
                    expect(result).to(beNil())
                }
            }
            
            context("Stats and logic") {
            
                let entity = Entity(["hp": 40])
                let enemy = Entity(["hp": 20])
                entity.target = enemy
                
                
                it("should be able to read the hp it both the entity and its target") {
                    let result = parse(entity.parser, ArraySlice(["hp"]))
                    expect(result).to(equal(40))
                    
                    let result2 = parse(entity.parser, ArraySlice(["target", "hp"]))
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

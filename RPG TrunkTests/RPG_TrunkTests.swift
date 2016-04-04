import Quick
import Nimble

@testable import RPGTrunk

class InterpreterSpec: QuickSpec {
    
    override func spec() {
        describe("Interpreter") {
            let env = RPGameEnvironment(delegate: DefaultGame())
            RPGameEnvironment.pushEnvironment(env)
            
            let entity = RPEntity()
            let enemy = RPEntity()
            entity.target = enemy
            
            context("getTarget") {
                it("should return the entity's target") {
                    let result = getTarget(entity)
                    expect(result == PropertyResultType.Entity(entity: enemy)).to(beTrue())
                }
                
                it("should return .Nothing when the target is nil") {
                    let result = getTarget(enemy)
                    expect(result == .Nothing).to(beTrue())
                }
            }
            
            /*
            context("parseTerms") {
                it("should return a .Target type EntityPropertyHandler") {
                    let result = parseTerms("target")
                    let targetResult = result[0]!(entity)
                    expect(targetResult == PropertyResultType.Entity(entity: enemy)).to(beTrue())
                }
            }
            
            context("interpretProperties") {
                it("should return a .Target type EntityPropertyHandler") {
                    let result = parseTerms("target")
                    expect(result.count).to(equal(1))
                    
                    let targetResult = result[0]!(entity)
                    expect(targetResult == PropertyResultType.Entity(entity: enemy)).to(beTrue())
                }
            }
            
            context("getEntityPropertyHandler") {
                it("should return nil when property requested is invalid") {
                    let prop = getPropertyHandler("blahblah")
                    expect(prop).to(beNil())
                }
            }
             */
        }
    }
}

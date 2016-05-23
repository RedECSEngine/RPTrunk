
import Quick
import Nimble

@testable import RPTrunk

class StatusEffectSpec: QuickSpec {
    
    override func spec() {
        describe("Status Effects") {
            
            it("should be cooling down when there are charges") {
               
                let se = StatusEffect(identity: "Test", components: [], duration: nil, charges: 1)
                let activeSE = ActiveStatusEffect(se)
                
                expect(activeSE.isCoolingDown()).to(beTrue())
                
            }
            
        }
    }
}

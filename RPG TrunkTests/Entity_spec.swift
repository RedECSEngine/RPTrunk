import Quick
import Nimble

@testable import RPTrunk

class EntitySpec: QuickSpec {
    
    override func spec() {
        
        describe("Entity") {
            
            let env = RPGameEnvironment(delegate: DefaultGame())
            RPGameEnvironment.pushEnvironment(env)
            
            var entity:Entity!
            var enemy:Entity!
            
            beforeEach {
            
                entity = Entity(["hp":30])
                enemy = Entity(["hp":30])
            }
            
            context("stats") {
                
                it("should be able to have any stats value within the baseStats range") {
                
                    entity.setCurrentStats(["hp": 15])
                    expect(entity["hp"]).to(equal(15))
                }
                
                it("should not be able to exceed base stats") {
                    
                    entity.setCurrentStats(["hp": 45])
                    expect(entity["hp"]).to(equal(30))
                }
            }
            
            context("passive abilities") {
                
                it("should trigger on event occurences") {
                
                    let ability = Ability(name: "Test")
                    entity.addPassiveAbility(ability, conditional: .Always)
                    
                    let enemyAbility = Ability(name: "enemyAbility")
                    let fakeEvent = Event(initiator: enemy, ability: enemyAbility)
                    
                    let reactionEvents = entity.eventDidOccur(fakeEvent)
                    expect(reactionEvents.count).to(equal(1))
                    expect(reactionEvents.first!.ability).to(equal(ability))
                }
            }
            
            context("Status Effects") {
                
                it("should be able to remove status effect by name") {
                    let id = Identity(name: "Death", labels: ["KO"])
                    let se = StatusEffect(identity: id, components: [], duration: nil, charges: 1)
                    entity.applyStatusEffect(se)
                    
                    expect(entity.hasStatus("Death")).to(equal(true))
                    
                    entity.dischargeStatusEffect("KO")
                    expect(entity.hasStatus("Death")).to(equal(false))
                }
                
                it("should take several discharges to remove a status effect with multiple charges") {
                    let id = Identity(name: "Charge", labels: ["boost"])
                    let se = StatusEffect(identity: id, components: [], duration: nil, charges: 2)
                    entity.applyStatusEffect(se)
                    
                    expect(entity.hasStatus("Charge")).to(equal(true))
                    
                    entity.dischargeStatusEffect("boost")
                    expect(entity.hasStatus("Charge")).to(equal(true))
                    
                    entity.dischargeStatusEffect("boost")
                    expect(entity.hasStatus("Charge")).to(equal(false))
                }
            }
            
        } // /describe("entity")
        
    } // /spec()
}

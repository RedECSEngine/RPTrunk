
import Quick
import Nimble

@testable import RPTrunk

class StatsSpec: QuickSpec {
    
    override func spec() {
        describe("Stats") {
            
            it("should be able to logically compare stats") {
                
                let statsA = Stats(["hp": 0, "damage": 0])
                let statsB = Stats(["hp": 0, "damage": 2])
                expect(statsA < statsB).to(beTrue())
                
                let statsC = Stats(["hp": 0, "damage": 2])
                let statsD = Stats()
                expect(statsC < statsD).to(beFalse())
                
                let statsE = Stats()
                let statsF = Stats(["hp": 0, "damage": 2])
                expect(statsE < statsF).to(beTrue())
                
                let statsG = Stats()
                let statsH = Stats(["hp": 1, "damage": 2])
                expect(statsG < statsH).to(beTrue())
                
                let statsI = Stats(["hp":30, "damage": 0, "agility": 0])
                let statsJ = Stats(["hp":0, "damage": 0, "agility": 5])
                expect(statsI >= statsJ).to(beFalse())
            }
            
        }
    }
}

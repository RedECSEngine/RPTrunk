
import XCTest
import Nimble
@testable import RPTrunk

class Stats_spec: XCTestCase {
    
    func test_should_be_able_to_compare_stats_where_all_conditions_must_be_met() {
        
        let statsA = RPStats(["hp": 0, "damage": 0])
        let statsB = RPStats(["hp": 0, "damage": 2])
        expect(statsA < statsB).to(beTrue())
        
        let statsC = RPStats(["hp": 0, "damage": 2])
        let statsD = RPStats()
        expect(statsC < statsD).to(beFalse())
        
        let statsE = RPStats()
        let statsF = RPStats(["hp": 0, "damage": 2])
        expect(statsE < statsF).to(beTrue())
        
        let statsG = RPStats()
        let statsH = RPStats(["hp": 1, "damage": 2])
        expect(statsG < statsH).to(beTrue())
        
        let statsI = RPStats(["hp":30, "damage": 0, "agility": 0])
        let statsJ = RPStats(["hp":0, "damage": 0, "agility": 5])
        expect(statsI >= statsJ).to(beFalse())
    }
}

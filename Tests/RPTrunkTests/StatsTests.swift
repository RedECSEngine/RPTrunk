@testable import RPTrunk
import XCTest

final class StatsTests: XCTestCase {
    static var allTests = [
        ("testLogicalStatsComparison", testLogicalStatsComparison),
    ]

    func testLogicalStatsComparison() {
        let statsA = TestStats(dict: ["hp": 0, "damage": 0])
        let statsB = TestStats(dict: ["hp": 0, "damage": 2])
        XCTAssertEqual(statsA < statsB, true)

        let statsC = TestStats(dict: ["hp": 0, "damage": 2])
        let statsD = TestStats()
        XCTAssertEqual(statsC < statsD, false)

        let statsE = TestStats()
        let statsF = TestStats(dict: ["hp": 0, "damage": 2])
        XCTAssertEqual(statsE < statsF, true)

        let statsG = TestStats()
        let statsH = TestStats(dict: ["hp": 1, "damage": 2])
        XCTAssertEqual(statsG < statsH, true)

        let statsI = TestStats(dict: ["hp": 30, "damage": 0, "agility": 0])
        let statsJ = TestStats(dict: ["hp": 0, "damage": 0, "agility": 5])
        XCTAssertEqual(statsI >= statsJ, false)
    }
}

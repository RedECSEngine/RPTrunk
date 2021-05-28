@testable import RPTrunk
import XCTest

final class StatsTests: XCTestCase {
    static var allTests = [
        ("testLogicalStatsComparison", testLogicalStatsComparison),
    ]

    func testLogicalStatsComparison() {
        let statsA = Stats(["hp": 0, "damage": 0])
        let statsB = Stats(["hp": 0, "damage": 2])
        XCTAssertEqual(statsA < statsB, true)

        let statsC = Stats(["hp": 0, "damage": 2])
        let statsD = Stats()
        XCTAssertEqual(statsC < statsD, false)

        let statsE = Stats()
        let statsF = Stats(["hp": 0, "damage": 2])
        XCTAssertEqual(statsE < statsF, true)

        let statsG = Stats()
        let statsH = Stats(["hp": 1, "damage": 2])
        XCTAssertEqual(statsG < statsH, true)

        let statsI = Stats(["hp": 30, "damage": 0, "agility": 0])
        let statsJ = Stats(["hp": 0, "damage": 0, "agility": 5])
        XCTAssertEqual(statsI >= statsJ, false)
    }
}

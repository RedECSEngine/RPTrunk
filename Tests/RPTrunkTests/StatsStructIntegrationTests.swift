import Foundation
@testable import RPTrunk
import XCTest

final class StatsStructIntegrationTests: XCTestCase {
    func testZeroHasAllPropertiesAtZero() {
        let zero = TestStats.zero
        XCTAssertEqual(zero.hp, 0)
        XCTAssertEqual(zero.mana, 0)
        XCTAssertEqual(zero.damage, 0)
        XCTAssertEqual(zero.agility, 0)
    }

    func testDynamicKeysExposeEveryStoredProperty() {
        XCTAssertEqual(
            Set(TestStats.dynamicKeys.keys),
            ["hp", "mana", "damage", "agility"]
        )
        XCTAssertEqual(TestStats.numericAndComparableKeys.count, 4)
    }

    func testDictionaryInitRoundTripsThroughSubscript() {
        let stats = TestStats(dict: ["hp": 12, "agility": 3])
        XCTAssertEqual(stats.hp, 12)
        XCTAssertEqual(stats.agility, 3)
        XCTAssertEqual(stats["hp"], 12)
        XCTAssertEqual(stats["mana"], 0)
    }

    func testIntegerLiteralFillsEveryProperty() {
        let stats: TestStats = 7
        XCTAssertEqual(stats.hp, 7)
        XCTAssertEqual(stats.mana, 7)
        XCTAssertEqual(stats.damage, 7)
        XCTAssertEqual(stats.agility, 7)
    }

    func testArithmeticAppliesPropertyWise() {
        let a = TestStats(dict: ["hp": 10, "mana": 4, "damage": 2])
        let b = TestStats(dict: ["hp": 3, "mana": 1, "agility": 5])

        let sum = a + b
        XCTAssertEqual(sum, TestStats(dict: ["hp": 13, "mana": 5, "damage": 2, "agility": 5]))

        let difference = a - b
        XCTAssertEqual(difference, TestStats(dict: ["hp": 7, "mana": 3, "damage": 2, "agility": -5]))

        let product = a * TestStats(dict: ["hp": 2, "mana": 2, "damage": 2, "agility": 2])
        XCTAssertEqual(product, TestStats(dict: ["hp": 20, "mana": 8, "damage": 4]))
    }

    func testComparisonMatchesAnyPropertyLessThanSemantics() {
        let lower = TestStats(dict: ["hp": 1])
        let higher = TestStats(dict: ["hp": 2])
        XCTAssertTrue(lower < higher)
        XCTAssertFalse(higher < lower)
        XCTAssertFalse(TestStats.zero < TestStats.zero)
    }

    func testCodableRoundTrip() throws {
        let original = TestStats(dict: ["hp": 42, "mana": 9, "damage": 6, "agility": 1])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TestStats.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

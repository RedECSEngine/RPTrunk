import XCTest
@testable import RPTrunk

private typealias TestItemDefinition = TestStats.ItemDefinition<EmptyMetadataDictionary>

private struct RawItemDefinition: RPItemDefining {
    typealias Metadata = EmptyMetadataDictionary

    var code: RPReferenceCode
    var displayName: String?
    var tags: String?
    var equipmentSlotCode: String?
    var maxNumberOfOptionalStats: Int?
    var metadata: EmptyMetadataDictionary?
    var statCells: [String: String]
}

final class ItemDefinitionStatVariationTests: XCTestCase {
    func testBareNumberIsAnOptionalDegenerateRange() throws {
        let variation = try RPItemDefinitionStatVariation(parsing: "5")
        XCTAssertEqual(variation.lowerBound, 5)
        XCTAssertEqual(variation.upperBound, 5)
        XCTAssertFalse(variation.isRequired)
        XCTAssertTrue(variation.isFixed)
        XCTAssertEqual(variation.ceiling, 0)
    }

    func testRangeIsOptional() throws {
        let variation = try RPItemDefinitionStatVariation(parsing: "1-2")
        XCTAssertEqual(variation.lowerBound, 1)
        XCTAssertEqual(variation.upperBound, 2)
        XCTAssertFalse(variation.isRequired)
        XCTAssertFalse(variation.isFixed)
        XCTAssertEqual(variation.ceiling, 1)
    }

    func testBangMakesItRequired() throws {
        let ranged = try RPItemDefinitionStatVariation(parsing: "5-10!")
        XCTAssertTrue(ranged.isRequired)
        XCTAssertFalse(ranged.isFixed)
        XCTAssertEqual(ranged.ceiling, 5)

        let bare = try RPItemDefinitionStatVariation(parsing: "1!")
        XCTAssertTrue(bare.isRequired)
        XCTAssertTrue(bare.isFixed)
    }

    func testSurroundingWhitespaceIsTolerated() throws {
        XCTAssertEqual(try RPItemDefinitionStatVariation(parsing: " 1 - 2 ").upperBound, 2)
        XCTAssertTrue(try RPItemDefinitionStatVariation(parsing: " 3 ! ").isRequired)
    }

    func testALeadingMinusBelongsToTheLowerBound() throws {
        let variation = try RPItemDefinitionStatVariation(parsing: "-2-5")
        XCTAssertEqual(variation.lowerBound, -2)
        XCTAssertEqual(variation.upperBound, 5)
    }

    func testMalformedCellsThrow() {
        XCTAssertThrowsError(try RPItemDefinitionStatVariation(parsing: "")) { error in
            XCTAssertEqual(error as? RPItemDefinitionStatVariationError, .empty)
        }
        XCTAssertThrowsError(try RPItemDefinitionStatVariation(parsing: "abc")) { error in
            XCTAssertEqual(error as? RPItemDefinitionStatVariationError, .malformed("abc"))
        }
        XCTAssertThrowsError(try RPItemDefinitionStatVariation(parsing: "5--2")) { error in
            XCTAssertEqual(error as? RPItemDefinitionStatVariationError, .invertedRange("5--2"))
        }
    }
}

final class ItemDefinitionLoadingTests: XCTestCase {
    private func blade() -> TestItemDefinition {
        TestItemDefinition(
            code: "blade",
            displayName: "Blade",
            equipmentSlotCode: "weapon",
            maxNumberOfOptionalStats: 1,
            hp: "10!",
            mana: "1-2",
            damage: "5-10!",
            agility: "5"
        )
    }

    func testCellsRouteToFixedRequiredAndOptional() throws {
        let cache = RPCache<TestRPSpace>()
        try cache.loadItemDefinitions([blade()])

        let item = try cache.getItem("blade")
        XCTAssertEqual(item.displayName, "Blade")
        XCTAssertEqual(item.equipmentSlotCode, "weapon")
        XCTAssertEqual(item.stats.hp, 10, "a bare number with ! is fixed on the item")
        XCTAssertEqual(item.stats.damage, 0, "a required range is not on the base item")

        let drop = try XCTUnwrap(cache.lootTableItems["blade"])
        XCTAssertEqual(drop.itemCode, "blade")
        XCTAssertEqual(drop.maxNumberOfOptionalStats, 1)
        XCTAssertEqual(drop.requiredVariations.count, 1)
        XCTAssertEqual(drop.requiredVariations.first?.fragment.stats?.damage, 5)
        XCTAssertEqual(drop.requiredVariations.first?.variableStats?.damage, 5)
        XCTAssertEqual(drop.optionalVariations.count, 2, "agility and mana are optional")
    }

    func testOptionalVariationsCarryTheirOwnStatInSortedKeyOrder() throws {
        let cache = RPCache<TestRPSpace>()
        try cache.loadItemDefinitions([blade()])
        let drop = try XCTUnwrap(cache.lootTableItems["blade"])

        XCTAssertEqual(drop.optionalVariations.count, 2)

        var agilityOnly = TestStats.zero
        agilityOnly.agility = 5
        let agility = drop.optionalVariations[0]
        XCTAssertEqual(
            agility.fragment.stats, agilityOnly,
            "variations follow sorted stat-key order, so agility comes first, and it touches no other stat"
        )

        var manaOnly = TestStats.zero
        manaOnly.mana = 1
        let mana = drop.optionalVariations[1]
        XCTAssertEqual(
            mana.fragment.stats, manaOnly,
            "mana sorts after agility, and it touches no other stat"
        )
    }

    func testABareNumberHasNothingToRollButARangeCarriesACeiling() throws {
        let cache = RPCache<TestRPSpace>()
        try cache.loadItemDefinitions([blade()])
        let drop = try XCTUnwrap(cache.lootTableItems["blade"])

        let agility = drop.optionalVariations[0]
        XCTAssertEqual(agility.fragment.stats?.agility, 5, "agility 5 is the whole value")
        XCTAssertNil(
            agility.variableStats,
            "a degenerate range carries no ceiling at all, so rolledStats is skipped rather than rolling 0...0"
        )
        XCTAssertEqual(agility.chance, RPChance.certain)

        var manaCeiling = TestStats.zero
        manaCeiling.mana = 1
        let mana = drop.optionalVariations[1]
        XCTAssertEqual(mana.fragment.stats?.mana, 1, "mana 1-2 lands as base 1")
        XCTAssertEqual(mana.variableStats, manaCeiling, "plus a ceiling of 1, so it rolls 1...2")
        XCTAssertEqual(mana.chance, RPChance.certain)
    }

    func testTagsAreSplitOnCommas() throws {
        let cache = RPCache<TestRPSpace>()
        var definition = blade()
        definition.tags = "melee,sharp"
        try cache.loadItemDefinitions([definition])
        XCTAssertEqual(try cache.getItem("blade").tags, ["melee", "sharp"])
    }

    func testAnUnknownStatKeyThrows() {
        let cache = RPCache<TestRPSpace>()
        let definition = RawItemDefinition(
            code: "bogus",
            displayName: nil,
            tags: nil,
            equipmentSlotCode: nil,
            maxNumberOfOptionalStats: nil,
            metadata: nil,
            statCells: ["notAStat": "1-2"]
        )
        XCTAssertThrowsError(try cache.loadItemDefinitions([definition]))
    }

    func testRequiredAlwaysAppliesAndOptionalsHonourTheCap() throws {
        TestRPSpace.resetTestHooks()
        defer { TestRPSpace.resetTestHooks() }
        TestRPSpace.randomRule = { _ in 0 }

        let cache = RPCache<TestRPSpace>()
        try cache.loadItemDefinitions([blade()])
        let drop = try XCTUnwrap(cache.lootTableItems["blade"])
        cache.lootTables["table"] = RPLootTable(code: "table", items: [drop], maxItemsDropped: 1)

        let result = try XCTUnwrap(cache.lootResult(forLootTableCode: "table"))
        let stats = try XCTUnwrap(result.items.first).stats

        XCTAssertEqual(stats.hp, 10, "the fixed stat is on every copy")
        XCTAssertEqual(stats.damage, 5, "the required range rolled its lower bound")
        XCTAssertEqual(stats.agility, 5, "the first optional was drawn")
        XCTAssertEqual(stats.mana, 0, "only one optional fits the cap")
    }

    func testACapOfZeroAppliesNoOptionals() throws {
        TestRPSpace.resetTestHooks()
        defer { TestRPSpace.resetTestHooks() }
        TestRPSpace.randomRule = { _ in 0 }

        let cache = RPCache<TestRPSpace>()
        var definition = blade()
        definition.maxNumberOfOptionalStats = 0
        try cache.loadItemDefinitions([definition])
        let drop = try XCTUnwrap(cache.lootTableItems["blade"])
        cache.lootTables["table"] = RPLootTable(code: "table", items: [drop], maxItemsDropped: 1)

        let stats = try XCTUnwrap(
            XCTUnwrap(cache.lootResult(forLootTableCode: "table")).items.first
        ).stats
        XCTAssertEqual(stats.damage, 5, "required is unaffected by the cap")
        XCTAssertEqual(stats.agility, 0)
        XCTAssertEqual(stats.mana, 0)
    }
}

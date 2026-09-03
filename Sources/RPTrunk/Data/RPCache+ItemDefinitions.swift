extension RPCache {
    public func loadItemDefinitions<D: RPItemDefining>(
        _ definitions: [D]
    ) throws where D.Metadata == RP.ItemMetadata {
        for definition in definitions {
            var fixedStats = RP.Stats.zero
            var required: [RPFragmentVariation<RP>] = []
            var optional: [RPFragmentVariation<RP>] = []

            let cells = definition.statCells
            for key in cells.keys.sorted() {
                guard RP.Stats.dynamicKeys[key] != nil else {
                    throw CacheError.invalidFormat(
                        "item `\(definition.code)` declares stat `\(key)`, "
                            + "which is not a key of \(RP.Stats.self)"
                    )
                }
                let variation = try RPItemDefinitionStatVariation(parsing: cells[key]!)
                switch (variation.isRequired, variation.isFixed) {
                case (true, true):
                    fixedStats[key] = variation.lowerBound
                case (true, false):
                    required.append(Self.fragmentVariation(key: key, variation: variation))
                case (false, _):
                    optional.append(Self.fragmentVariation(key: key, variation: variation))
                }
            }

            var item = RPItem<RP>(
                code: definition.code,
                displayName: definition.displayName,
                tags: Self.tags(from: definition.tags),
                fragments: fixedStats == .zero ? [] : [RPFragment(stats: fixedStats)],
                equipmentSlotCode: definition.equipmentSlotCode.map(RPEquipmentSlotCode.init)
            )
            item.metadata = definition.metadata
            items[definition.code] = item

            lootTableItems[definition.code] = RPLootTableItem(
                itemCode: definition.code,
                requiredVariations: required,
                optionalVariations: optional,
                maxNumberOfOptionalStats: definition.maxNumberOfOptionalStats ?? 0
            )
        }
    }

    private static func tags(from list: String?) -> Set<RPItemTag> {
        Set(
            (list ?? "")
                .split(separator: ",")
                .map { RPItemTag(String($0)) }
                .filter { !$0.rawValue.isEmpty }
        )
    }

    private static func fragmentVariation(
        key: String,
        variation: RPItemDefinitionStatVariation
    ) -> RPFragmentVariation<RP> {
        var stats = RP.Stats.zero
        stats[key] = variation.lowerBound
        var ceiling = RP.Stats.zero
        ceiling[key] = variation.ceiling
        return RPFragmentVariation(
            fragment: RPFragment(stats: stats),
            variableStats: variation.isFixed ? nil : ceiling,
            chance: RPChance.certain
        )
    }
}

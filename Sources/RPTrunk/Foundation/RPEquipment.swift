/// The `RPEquipment` slot an item is worn in.
public struct RPEquipmentSlotCode: RPIdentifierCode {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct RPEquipment<RP: RPSpace>: Codable, Equatable {
    public private(set) var equipmentSlots: [RPEquipmentSlotCode: [RPActiveItem<RP>]] = [:]

    /// How many items each slot admits. A slot with no entry is unlimited.
    public var equipmentSlotCapacities: [RPEquipmentSlotCode: Int] = [:]

    /// Everything currently worn, ordered by slot code so the sequence never
    /// depends on dictionary hashing.
    public var wornItems: [RPActiveItem<RP>] {
        equipmentSlots.keys.sorted().flatMap { equipmentSlots[$0] ?? [] }
    }

    public init(equipmentSlotCapacities: [RPEquipmentSlotCode: Int] = [:]) {
        self.equipmentSlotCapacities = equipmentSlotCapacities
    }

    public func items(inSlot code: RPEquipmentSlotCode) -> [RPActiveItem<RP>] {
        equipmentSlots[code] ?? []
    }

    /// `nil` when the slot admits any number of items.
    public func capacity(ofSlot code: RPEquipmentSlotCode) -> Int? {
        equipmentSlotCapacities[code]
    }

    public func hasRoom(inSlot code: RPEquipmentSlotCode) -> Bool {
        guard let capacity = capacity(ofSlot: code) else { return true }
        return items(inSlot: code).count < capacity
    }

    public func canEquip(_ item: RPActiveItem<RP>) -> Bool {
        guard let code = item.equipmentSlotCode else { return false }
        return hasRoom(inSlot: code)
    }

    /// Wears `item`, failing when it is not equippable or its slot is full.
    /// Which item to displace in order to make room is the caller's policy —
    /// unequip first, then equip.
    @discardableResult
    public mutating func equip(_ item: RPActiveItem<RP>) -> Bool {
        guard let code = item.equipmentSlotCode, hasRoom(inSlot: code) else {
            return false
        }
        equipmentSlots[code, default: []].append(item)
        return true
    }

    @discardableResult
    public mutating func unequip(itemId: RPItemId) -> RPActiveItem<RP>? {
        for (code, items) in equipmentSlots {
            guard let index = items.firstIndex(where: { $0.id == itemId }) else {
                continue
            }
            let removed = equipmentSlots[code]?.remove(at: index)
            if equipmentSlots[code]?.isEmpty == true {
                equipmentSlots[code] = nil
            }
            return removed
        }
        return nil
    }

    @discardableResult
    public mutating func unequipAll() -> [RPActiveItem<RP>] {
        let removed = wornItems
        equipmentSlots = [:]
        return removed
    }
}

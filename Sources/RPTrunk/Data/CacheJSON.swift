public struct RPCacheJSON<RP: RPSpace>: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case statusEffects = "Status Effects"
        case abilities = "Abilities"
        case bodies = "Bodies"
        case items = "Items"
    }

    public var abilities: [String: RPAbilityJSON<RP>]?
    public var statusEffects: [String: RPStatusEffectJSON<RP>]?
    public var bodies: [String: RPBodyJSON<RP>]?
    public var items: [String: RPItemJSON<RP>]?
}

public protocol RPFragmentsContainerJSON {
    associatedtype Stats: StatsType
    var stats: Stats? { get }
    var cost: Stats? { get }
    var requirements: Stats? { get }
    var statusEffects: [String]? { get }
    var target: String? { get }
    var discharge: [String]? { get }
    var fragments: [String]? { get }
}

public struct RPStatusEffectJSON<RP: RPSpace>: Codable, Equatable, RPFragmentsContainerJSON {
    public var displayName: String?
    public var stats: RP.Stats?
    public var cost: RP.Stats?
    public var requirements: RP.Stats?
    public var statusEffects: [String]?
    public var target: String?
    public var discharge: [String]?
    public var fragments: [String]?

    public var duration: RPTimeIncrement?
    public var charges: Int?
    public var impairsAction: Bool? = false
    /// Time (ms) between periodic pulses; omitted uses `RPStatusEffect.defaultPeriod`.
    public var period: RPTimeIncrement?
}

public struct RPBodyJSON<RP: RPSpace>: Codable, Equatable {
    public struct AbilityReferenceJSON: Codable, Equatable {
        var code: String
        var conditional: String
    }

    public var displayName: String?
    public var stats: RP.Stats? = .zero
    public var abilities: [AbilityReferenceJSON]?

    /// This body's equipment slots and how many items each admits. Slots left
    /// undeclared are unlimited, so declare every slot that should be capped.
    public var equipmentSlots: [RPEquipmentSlotCode: Int]?

    public var metadata: RP.BodyMetadata?
}

public struct RPAbilityJSON<RP: RPSpace>: Codable, Equatable, RPFragmentsContainerJSON {
    public var displayName: String?
    public var stats: RP.Stats?
    public var cost: RP.Stats?
    public var requirements: RP.Stats?
    public var statusEffects: [String]?
    public var target: String?
    public var discharge: [String]?
    public var fragments: [String]?

    public let cooldown: RPTimeIncrement?

    public var metadata: RP.AbilityMetadata?
}

public struct RPItemJSON<RP: RPSpace>: Codable, Equatable, RPFragmentsContainerJSON {
    public var displayName: String?
    public var stats: RP.Stats?
    public var cost: RP.Stats?
    public var requirements: RP.Stats?
    public var statusEffects: [String]?
    public var target: String?
    public var discharge: [String]?
    public var fragments: [String]?

    public var ability: String?
    public var conditional: String?
    public var cooldown: RPTimeIncrement?
    public var maximumStack: Int?

    /// The `RPEquipment` slot this item is worn in. Omitted means not equippable.
    public var equipmentSlotCode: RPEquipmentSlotCode?

    public var metadata: RP.ItemMetadata?
}

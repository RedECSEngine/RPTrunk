public struct RPCacheJSON<RP: RPSpace>: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case statusEffects = "Status Effects"
        case abilities = "Abilities"
        case entities = "Entities"
        case items = "Items"
    }

    public var abilities: [String: AbilityJSON<RP>]?
    public var statusEffects: [String: StatusEffectJSON<RP>]?
    public var entities: [String: EntityJSON<RP>]?
    public var items: [String: ItemJSON<RP>]?
}

public protocol ComponentsContainerJSON {
    associatedtype Stats: StatsType
    var stats: Stats? { get }
    var cost: Stats? { get }
    var requirements: Stats? { get }
    var statusEffects: [String]? { get }
    var target: String? { get }
    var discharge: [String]? { get }
    var components: [String]? { get }
}

public struct StatusEffectJSON<RP: RPSpace>: Codable, Equatable, ComponentsContainerJSON {
    public var displayName: String?
    public var stats: RP.Stats?
    public var cost: RP.Stats?
    public var requirements: RP.Stats?
    public var statusEffects: [String]?
    public var target: String?
    public var discharge: [String]?
    public var components: [String]?

    public var duration: RPTimeIncrement?
    public var charges: Int?
    public var impairsAction: Bool? = false
    /// Time (ms) between periodic pulses; omitted uses `StatusEffect.defaultPeriod`.
    public var period: RPTimeIncrement?
}

public struct EntityJSON<RP: RPSpace>: Codable, Equatable {
    public struct AbilityJSON: Codable, Equatable {
        var code: String
        var conditional: String
    }
    
    public var displayName: String?
    public var stats: RP.Stats? = .zero
    public var abilities: [AbilityJSON]?
    
    public var metadata: RP.EntityMetadata?
}

public struct AbilityJSON<RP: RPSpace>: Codable, Equatable, ComponentsContainerJSON {
    public var displayName: String?
    public var stats: RP.Stats?
    public var cost: RP.Stats?
    public var requirements: RP.Stats?
    public var statusEffects: [String]?
    public var target: String?
    public var discharge: [String]?
    public var components: [String]?

    public let cooldown: RPTimeIncrement?

    public var metadata: RP.AbilityMetadata?
}

public struct ItemJSON<RP: RPSpace>: Codable, Equatable, ComponentsContainerJSON {
    public var displayName: String?
    public var stats: RP.Stats?
    public var cost: RP.Stats?
    public var requirements: RP.Stats?
    public var statusEffects: [String]?
    public var target: String?
    public var discharge: [String]?
    public var components: [String]?

    public var ability: String?
    public var conditional: String?
    public var cooldown: RPTimeIncrement?

    public var metadata: RP.ItemMetadata?
}

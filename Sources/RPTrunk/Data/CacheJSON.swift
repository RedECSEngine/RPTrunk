import Foundation

public struct RPCacheJSON<Stats: StatsType>: Codable {
    enum CodingKeys: String, CodingKey {
        case statusEffects = "Status Effects"
        case abilities = "Abilities"
        case entities = "Entities"
    }
    
    public var abilities: [String: AbilityJSON<Stats>]?
    public var statusEffects: [String: StatusEffectJSON<Stats>]?
    public var entities: [String: EntityJSON<Stats>]?
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

public struct StatusEffectJSON<Stats: StatsType>: Codable, ComponentsContainerJSON {
    public var stats: Stats?
    public var cost: Stats?
    public var requirements: Stats?
    public var statusEffects: [String]?
    public var target: String?
    public var discharge: [String]?
    public var components: [String]?

    public var duration: RPTimeIncrement?
    public var charges: Int?
    public var impairsAction: Bool? = false
}

public struct EntityJSON<Stats: StatsType>: Codable {
    public struct AbilityJSON: Codable {
        var name: String
        var conditional: String
    }
    
    var stats: Stats? = .zero
    var abilities: [AbilityJSON]?
}

public struct AbilityJSON<Stats: StatsType>: Codable, ComponentsContainerJSON {
    public var stats: Stats?
    public var cost: Stats?
    public var requirements: Stats?
    public var statusEffects: [String]?
    public var target: String?
    public var discharge: [String]?
    public var components: [String]?

    public let cooldown: RPTimeIncrement?

    public var metadata: [String: String]?
}

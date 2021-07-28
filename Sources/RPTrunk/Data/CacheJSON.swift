import Foundation

public struct RPCacheJSON: Codable {
    enum CodingKeys: String, CodingKey {
        case statusEffects = "Status Effects"
        case abilities = "Abilities"
        case entities = "Entities"
    }
    
    public var abilities: [String: AbilityJSON]?
    public var statusEffects: [String: StatusEffectJSON]?
    public var entities: [String: EntityJSON]?
}

public protocol ComponentsContainerJSON {
    var stats: [String: RPValue]? { get }
    var cost: [String: RPValue]? { get }
    var requirements: [String: RPValue]? { get }
    var statusEffects: [String]? { get }
    var target: String? { get }
    var discharge: [String]? { get }
    var components: [String]? { get }
}

public struct StatusEffectJSON: Codable, ComponentsContainerJSON {
    public var stats: [String: RPValue]?
    public var cost: [String: RPValue]?
    public var requirements: [String: RPValue]?
    public var statusEffects: [String]?
    public var target: String?
    public var discharge: [String]?
    public var components: [String]?

    public var duration: RPTimeIncrement?
    public var charges: Int?
    public var impairsAction: Bool? = false
}

public struct EntityJSON: Codable {
    public struct AbilityJSON: Codable {
        var name: String
        var conditional: String
    }
    
    var stats: [String: RPValue]? = [:]
    var abilities: [AbilityJSON]?
}

public struct AbilityJSON: Codable, ComponentsContainerJSON {
    public var stats: [String: RPValue]?
    public var cost: [String: RPValue]?
    public var requirements: [String: RPValue]?
    public var statusEffects: [String]?
    public var target: String?
    public var discharge: [String]?
    public var components: [String]?

    public let cooldown: RPTimeIncrement?

    public var metadata: [String: String]?
}

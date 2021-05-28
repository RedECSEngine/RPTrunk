import Foundation

public struct Item: Temporal, ComponentContainer, Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case amount
        case currentTick
        case ability
        case conditional
    }

    public let name: String
    public var amount: Int = 1

    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement { ability?.cooldown ?? 0 }

    public weak var entity: Entity?
    let ability: Ability?
    public var conditional: Conditional

    public var components: [Component] = []

    public init(ability: Ability? = nil, conditional: Conditional) {
        name = "Untitled Item"
        self.ability = ability
        self.conditional = conditional
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        amount = try values.decode(Int.self, forKey: .amount)
        currentTick = try values.decode(RPTimeIncrement.self, forKey: .currentTick)
        ability = try values.decodeIfPresent(Ability.self, forKey: .ability)
        conditional = try values.decode(Conditional.self, forKey: .conditional)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(amount, forKey: .amount)
        try container.encode(currentTick, forKey: .currentTick)
        try container.encodeIfPresent(ability, forKey: .ability)
        try container.encode(conditional, forKey: .conditional)
    }

    public func canExecute() -> Bool {
        guard isCoolingDown() == false else {
            return false
        }

        guard let e = entity,
              let a = ability,
              e.allCurrentStats() > a.cost
        else {
            return false
        }

        return conditional.exec(e)
    }

    public func getPendingEvents(in rpSpace: RPSpace) -> [Event] {
        guard isCoolingDown() == false else {
            return []
        }
        return createEvents(in: rpSpace)
    }

    fileprivate func createEvents(in rpSpace: RPSpace) -> [Event] {
        guard let ability = self.ability,
              let entity = self.entity
        else {
            return []
        }
        return (0 ..< ability.repeats).map { _ in Event(initiator: entity, ability: ability, rpSpace: rpSpace) }
    }

    public mutating func tick(_ moment: Moment) {
        if isCoolingDown() {
            currentTick += moment.delta
        }
    }

    public mutating func resetCooldown() {
        currentTick = 0
    }

    public func copyForEntity(_ entity: Entity) -> Item {
        var newItemAbility = Item(ability: ability, conditional: conditional)
        newItemAbility.entity = entity
        return newItemAbility
    }
}

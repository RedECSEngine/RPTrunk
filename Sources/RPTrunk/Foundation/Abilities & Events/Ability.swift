
public struct Ability<RP: RPSpace>: ComponentContainer, Codable {
    public var name: String
    public var components: [Component<RP>]
    public var cooldown: RPTimeIncrement
    public var repeats: Int = 1
    public var metadata: [String: String]?

    public init(
        name: String,
        components: [Component<RP>] = [],
        cooldown: RPTimeIncrement? = nil
    ) {
        self.name = name
        self.components = components
        self.cooldown = cooldown ?? 0
    }
}

extension Ability: Equatable {}
public func == <RP: RPSpace>(lhs: Ability<RP>, rhs: Ability<RP>) -> Bool {
    lhs.name == rhs.name && lhs.isEqualTo(rhs)
}

/**
    An ability, currently active on an entity
 */
public struct ActiveAbility<RP: RPSpace>: Temporal, Codable {
    public typealias Stats = RP.Stats
    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement { ability.cooldown }

    public var entityId: RPEntityId
    public let ability: Ability<RP>
    public let conditional: Conditional<RP>

    public init(entityId: RPEntityId, ability: Ability<RP>, conditional: Conditional<RP>) {
        self.entityId = entityId
        self.ability = ability
        self.conditional = conditional
    }

    public func canExecute(in rpSpace: RP) -> Bool {
        guard isCoolingDown() == false else {
            return false
        }

        guard let e = rpSpace.entityById(entityId) else {
            return false
        }

        // TODO: consider stats cost
        // TODO: consider requirements
        // TODO: consider item exchange cost

        return (try? conditional.exec(e, rpSpace: rpSpace)) ?? false
    }

    public func getPendingEvents(in rpSpace: RP) -> [Event<RP>] {
        guard isCoolingDown() == false else {
            return []
        }
        return createEvents(in: rpSpace)
    }

    fileprivate func createEvents(in rpSpace: RP) -> [Event<RP>] {
        (0 ..< ability.repeats).map { _ in Event<RP>(initiator: entityId, ability: ability, rpSpace: rpSpace) }
    }

    public mutating func tick(_ moment: Moment) {
        if isCoolingDown() {
            currentTick += moment.delta
        }
    }

    public mutating func resetCooldown() {
        currentTick = 0
    }

    //TODO: revisit this function, was made pre-value type conversion
    public func copyForEntity(_ entity: RPEntity<RP>) -> ActiveAbility {
        ActiveAbility(entityId: entity.id, ability: ability, conditional: conditional)
    }
}


public struct Ability: ComponentContainer, Codable {
    public var name: String
    public var components: [Component]
    public var cooldown: RPTimeIncrement
    public var repeats: Int = 1
    public var metadata: [String: String]?

    public init(
        name: String,
        components: [Component] = [],
        cooldown: RPTimeIncrement? = nil
    ) {
        self.name = name
        self.components = components
        self.cooldown = cooldown ?? 0
    }
}

extension Ability: Equatable {}
public func == (lhs: Ability, rhs: Ability) -> Bool {
    lhs.name == rhs.name
        && lhs as ComponentContainer == rhs as ComponentContainer
}

public struct ActiveAbility: Temporal, Codable {
    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement { ability.cooldown }

    public var entityId: Id<Entity>
    public let ability: Ability
    public let conditional: Conditional

    public init(entityId: Id<Entity>, ability: Ability, conditional: Conditional) {
        self.entityId = entityId
        self.ability = ability
        self.conditional = conditional
    }

    public func canExecute(in rpSpace: RPSpace) -> Bool {
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

    public func getPendingEvents(in rpSpace: RPSpace) -> [Event] {
        guard isCoolingDown() == false else {
            return []
        }
        return createEvents(in: rpSpace)
    }

    fileprivate func createEvents(in rpSpace: RPSpace) -> [Event] {
        if let e = rpSpace.entityById(entityId) {
            return (0 ..< ability.repeats).map { _ in Event(initiator: e, ability: ability, rpSpace: rpSpace) }
        }
        return []
    }

    public mutating func tick(_ moment: Moment) {
        if isCoolingDown() {
            currentTick += moment.delta
        }
    }

    public mutating func resetCooldown() {
        currentTick = 0
    }

    public func copyForEntity(_ entity: Entity) -> ActiveAbility {
        ActiveAbility(entityId: entity.id, ability: ability, conditional: conditional)
    }
}

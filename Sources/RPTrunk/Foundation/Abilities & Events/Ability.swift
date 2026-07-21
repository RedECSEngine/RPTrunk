
public struct RPAbility<RP: RPSpace>: ComponentContainer, Codable {
    public var code: RPReferenceCode
    public var displayName: String
    public var components: [Component<RP>]
    public var cooldown: RPTimeIncrement
    public var repeats: Int = 1
    public var metadata: RP.AbilityMetadata?

    public init(
        code: RPReferenceCode,
        displayName: String? = nil,
        components: [Component<RP>] = [],
        cooldown: RPTimeIncrement? = nil
    ) {
        self.code = code
        self.displayName = displayName ?? code
        self.components = components
        self.cooldown = cooldown ?? 0
    }
}

extension RPAbility: Equatable {}
public func == <RP: RPSpace>(lhs: RPAbility<RP>, rhs: RPAbility<RP>) -> Bool {
    lhs.code == rhs.code && lhs.isEqualTo(rhs)
}

/**
    An ability, currently active on an entity
 */
public struct RPActiveAbility<RP: RPSpace>: Temporal, Codable {
    public typealias Stats = RP.Stats
    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement { ability.cooldown }

    public var entityId: RPEntityId
    public let ability: RPAbility<RP>
    public let conditional: Conditional<RP>

    public init(entityId: RPEntityId, ability: RPAbility<RP>, conditional: Conditional<RP>) {
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

    public func getPendingEvents(in rpSpace: RP) -> [RPEvent<RP>] {
        guard isCoolingDown() == false else {
            return []
        }
        return createEvents(in: rpSpace)
    }

    fileprivate func createEvents(in rpSpace: RP) -> [RPEvent<RP>] {
        (0 ..< ability.repeats).map { _ in RPEvent<RP>(initiator: entityId, ability: ability, rpSpace: rpSpace) }
    }

    public mutating func tick(_ moment: RPMoment) {
        if isCoolingDown() {
            currentTick += moment.delta
        }
    }

    public mutating func resetCooldown() {
        currentTick = 0
    }

    //TODO: revisit this function, was made pre-value type conversion
    public func copyForEntity(_ entity: RPEntity<RP>) -> RPActiveAbility {
        RPActiveAbility(entityId: entity.id, ability: ability, conditional: conditional)
    }
}

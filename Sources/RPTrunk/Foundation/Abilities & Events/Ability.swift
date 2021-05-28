
public struct Ability: ComponentContainer, Codable {

    public var name: String
    public var components: [Component]
    public var cooldown: RPTimeIncrement
    public var repeats: Int = 1
    public var metadata: [String: String]?
    
    public init(
        name: String,
        components: [Component] = [],
        shouldUseDefaults: Bool = true,
        cooldown: RPTimeIncrement? = nil
    ) {
        self.name = name
        self.components = components
        self.cooldown = cooldown ?? 0
        if shouldUseDefaults {
            self.components += RPGameEnvironment.current.delegate.abilityDefaults
        }
    }
}

extension Ability: Equatable {}
public func ==(lhs:Ability, rhs:Ability) -> Bool {
    return
        lhs.name == rhs.name
    && lhs as ComponentContainer == rhs as ComponentContainer
}

public struct ActiveAbility: Temporal, Codable {

    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement { return ability.cooldown }

    public var entityId: String
    public let ability: Ability
    public let conditional: Conditional
    
    public init(entityId: String, ability: Ability, conditional: Conditional) {
        self.entityId = entityId
        self.ability = ability
        self.conditional = conditional
    }
    
    public func canExecute(in rpSpace: RPSpace) -> Bool {
        guard false == isCoolingDown() else {
            return false
        }
        
        guard let e = rpSpace.entities[entityId] else {
            return false
        }
        
        // TODO: consider stats cost
        // TODO: consider requirements
        // TODO: consider item exchange cost
        
        return conditional.exec(e)
    }
    
    public func getPendingEvents(in rpSpace: RPSpace) -> [Event] {
        guard isCoolingDown() == false else {
            return []
        }
        return createEvents(in: rpSpace)
    }
    
    fileprivate func createEvents(in rpSpace: RPSpace) -> [Event] {
    
        if let e = rpSpace.entities[entityId] {
            return (0..<ability.repeats).map { _ in Event(initiator: e, ability: ability, rpSpace: rpSpace) }
        }
        return []
    }
    
    mutating public func tick(_ moment:Moment) {
        
        if isCoolingDown() {
            currentTick += moment.delta
        }
    }
    
    mutating public func resetCooldown() {
        currentTick = 0
    }
    
    public func copyForEntity(_ entity: Entity) -> ActiveAbility {
        
        return ActiveAbility(entityId: entity.id, ability: ability, conditional: conditional)
    }
    
}


public struct Ability: ComponentContainer {

    public var name:String
    public var components:[Component]
    public var cooldown:RPTimeIncrement
    public var repeats:Int = 1
    
    public init(name:String, components:[Component] = [], shouldUseDefaults:Bool = true, cooldown: RPTimeIncrement?) {
        self.name = name
        self.components = components
        self.cooldown = cooldown ?? 0
        if shouldUseDefaults {
            self.components += RPGameEnvironment.current.delegate.abilityDefaults
        }
    }
}

extension Ability:Equatable {}
public func ==(lhs:Ability, rhs:Ability) -> Bool {
    return
        lhs.name == rhs.name
    && lhs as ComponentContainer == rhs as ComponentContainer
}

public struct ActiveAbility: Temporal {
    
    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement { return ability.cooldown }
    public var conditional: Conditional
    public weak var entity: Entity?
    
    let ability:Ability
    
    public init(_ a: Ability, _ c:Conditional) {
        ability = a
        conditional = c
    }
    
    public func canExecute() -> Bool {
        guard false == isCoolingDown() else {
            return false
        }
        
        guard let e = entity else {
            return false
        }
        return conditional.exec(e)
    }
    
    public func getEvents() -> [Event] {
    
        if let e = entity {
            return (0..<ability.repeats).map { _ in Event(initiator: e, ability: ability) }
        }
        return []
    }
    
    mutating public func tick(_ moment:Moment) -> [Event] {
        
        if isCoolingDown() {
            currentTick += moment.delta
        }
        return []
    }
    
    mutating public func resetCooldown() {
        currentTick = 0
    }
    
    public func copyForEntity(_ entity:Entity) -> ActiveAbility {
        
        var newActiveAbility = ActiveAbility(ability, conditional)
        newActiveAbility.entity = entity
        return newActiveAbility
    }
    
}

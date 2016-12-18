
public struct Ability: ComponentContainer {

    public var name:String
    public var components:[Component]
    public var cooldown:Double { return 0 }
    public var repeats:Int = 1
    
    public init(name:String, components:[Component] = [], shouldUseDefaults:Bool = true) {
        self.name = name
        self.components = components
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

open class ActiveAbility: Temporal {
    
    open var currentTick: Double = 0
    open var maximumTick: Double { return ability.cooldown }
    open var conditional: Conditional
    open weak var entity: Entity?
    
    let ability:Ability
    
    public init(_ a: Ability, _ c:Conditional) {
        ability = a
        conditional = c
    }
    
    open func canExecute() -> Bool {
        guard let e = entity else {
            return false
        }
        return conditional.exec(e)
    }
    
    open func getEvents() -> [Event] {
    
        if let e = entity {
            return (0..<ability.repeats).map { _ in Event(initiator: e, ability: ability) }
        }
        return []
    }
    
    open func tick(_ moment:Moment) -> [Event] {
        
        if isCoolingDown() {
            currentTick += moment.delta
        }
        return []
    }
    
    open func resetCooldown() {
        currentTick = 0
    }
    
    open func copyForEntity(_ entity:Entity) -> ActiveAbility {
        
        let newActiveAbility = ActiveAbility(ability, conditional)
        newActiveAbility.entity = entity
        return newActiveAbility
    }
    
}


public struct Ability {

    public var name:String
    public var components:[Component]
    public var cooldown:Double { return 0 }
    public var repeats:Int = 1
    
    public var targetType:TargetType {
        return combineComponentTargetTypes(components)
    }
    
    public var stats: Stats {
        return combineComponentStats(components)
    }
    
    public var cost: Stats {
        return combineComponentCosts(components)
    }
    
    public var statusEffects: [StatusEffect] {
        return combineComponentStatusEffects(components)
    }
    
    public var dischargedStatusEffects: [String] {
        return combineComponentDischargedStatusEffects(components)
    }
    
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
    && componentsAreEqual(lhs.components,rhs.components)
}

public class ActiveAbility: Temporal {
    
    public var currentTick: Double = 0
    public var maximumTick: Double { return ability.cooldown }
    public var conditional: Conditional
    public weak var entity: Entity?
    
    let ability:Ability
    
    public init(_ a: Ability, _ c:Conditional) {
        ability = a
        conditional = c
    }
    
    public func canExecute() -> Bool {
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
    
    public func tick(moment:Moment) -> [Event] {
        
        if isCoolingDown() {
            currentTick += moment.delta
        }
        return []
    }
    
    public func resetCooldown() {
        currentTick = 0
    }
    
    public func copyForEntity(entity:Entity) -> ActiveAbility {
        
        let newActiveAbility = ActiveAbility(ability, conditional)
        newActiveAbility.entity = entity
        return newActiveAbility
    }
    
}
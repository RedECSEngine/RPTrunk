
public struct StatusEffect: Component {
    
    public let identity:Identity
    
    //both duration and charge can be used or one or the other
    let duration:Double? //the duration in AP
    let charges:Int? //the number of charges left
    let impairsAction:Bool
    let ability:Ability?
    
    public init(identity:Identity, components:[Component], duration:Double?, charges:Int?, impairsAction:Bool = false) {
        self.identity = identity
        self.duration = duration
        self.charges = charges
        self.impairsAction = impairsAction
        
        if components.count > 0 {
        
            let components:[Component] = components + [TargetType.Oneself(.Always)]
            ability = Ability(name: identity.name, components: components)
        } else {
            ability = nil
        }
    }
    
    public func getStatusEffects() -> [StatusEffect] {
        return [self]
    }
}

extension StatusEffect: Equatable {}

public func ==(lhs:StatusEffect, rhs:StatusEffect) -> Bool {
    return lhs.identity == rhs.identity
        && lhs.ability == rhs.ability
}

public class ActiveStatusEffect: Temporal {

    public var currentTick:Double = 0
    public var maximumTick:Double { return statusEffect.duration ?? 0 }
    
    var currentCharge:Int = 0
    
    var level:Int? // power level of the buff, if it is stackable
    
    public weak var entity: Entity?
    
    private let statusEffect: StatusEffect
    
    public var name:String { return statusEffect.identity.name }
    public var labels:[String] { return statusEffect.identity.labels }
    
    public init(_ se: StatusEffect) {
        statusEffect = se
        currentCharge = se.charges ?? 0
    }
    
    public func shouldDisableEntity() -> Bool {
        return statusEffect.impairsAction
    }
    
    public func tick(moment:Moment) -> [Event] {
        
        guard isCoolingDown() else {
            return []
        }
        
        currentTick += moment.delta
        
        if let entity = moment.parents.last as? Entity,
            let ability = statusEffect.ability {
            return [Event(initiator:entity, ability: ability)]
        }
        
        return []
    }
    
    public func resetCooldown() {
        currentTick = 0
    }
    
    public func expendCharge() {
    
        currentCharge -= 1
        if currentCharge <= 0 {
            currentTick = maximumTick
            return
        }
    }
    
    public func isCoolingDown() -> Bool {
        if statusEffect.duration != nil {
            return currentTick < maximumTick
        } else {
            return currentCharge != 0
        }
    }
}
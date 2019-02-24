
public struct StatusEffect: Codable {
   
    public let identity: Identity
    
    //both duration and charge can be used or one or the other
    let duration: RPTimeIncrement?
    let charges: Int? //the number of charges left
    let impairsAction: Bool
    let ability: Ability?
    
    public init(identity: Identity, components: [Component], duration: Double?, charges: Int?, impairsAction: Bool = false) {
        self.identity = identity
        self.duration = duration
        self.charges = charges
        self.impairsAction = impairsAction
        
        if components.count > 0 {
        
            let components: [Component] = components + [Targeting(.oneself, .always).toComponent()]
            ability = Ability(name: identity.name, components: components, cooldown: nil)
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

public struct ActiveStatusEffect: Temporal, Codable {

    fileprivate var deltaTick: RPTimeIncrement = 0
    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement { return statusEffect.duration ?? 0 }
    
    var currentCharge: Int = 0
    
    var level: Int? // power level of the buff, if it is stackable
    
    public var entityId: String
    fileprivate let statusEffect: StatusEffect
    
    public var identity: Identity { return statusEffect.identity }

    public init(entityId: String, statusEffect: StatusEffect) {
        self.entityId = entityId
        self.statusEffect = statusEffect
        self.currentCharge = statusEffect.charges ?? 0
    }
    
    public func shouldDisableEntity() -> Bool {
        return statusEffect.impairsAction
    }
    
    public func getPendingEvents(in rpSpace: RPSpace) -> [Event] {
        
        guard deltaTick > 1 else {
            return []
        }
        if let entity = rpSpace.entities[entityId]
            , let ability = statusEffect.ability {
            
            return [Event(category: .periodicEffect, initiator: entity, ability: ability, rpSpace: rpSpace)]
        }
        return []
    }
    
    mutating public func tick(_ moment: Moment) {
        
        guard isCoolingDown() else {
            return
        }
        
        deltaTick += moment.delta
    }

    mutating public func incrementTick() {
        deltaTick = 0
        currentTick += 1
    }
    
    mutating public func resetCooldown() {
        currentTick = 0
    }
    
    mutating public func expendCharge() {
    
        currentCharge -= 1
        if currentCharge <= 0 {
            currentTick = maximumTick
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
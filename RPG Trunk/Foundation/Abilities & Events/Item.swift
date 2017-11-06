import Foundation

public struct Item: Temporal, ComponentContainer {
    
    public let name: String = "Untitled Item"
    public var amount: Int = 1
    
    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement { return ability?.cooldown ?? 0 }
    
    public weak var entity: Entity?
    let ability: Ability?
    public var conditional: Conditional
    
    public var components: [Component] = []

    public init(ability: Ability? = nil, conditional: Conditional) {
        self.ability = ability
        self.conditional = conditional
    }
    
    public func canExecute() -> Bool {
        guard false == isCoolingDown() else {
            return false
        }
        
        guard let e = entity
            , let a = ability
            , e.allCurrentStats() > a.cost else {
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
        guard let ability = self.ability
            , let entity = self.entity else {
            return []
        }
        return (0..<ability.repeats).map { _ in Event(initiator: entity, ability: ability, rpSpace: rpSpace) }
    }
    
    mutating public func tick(_ moment:Moment) {
        
        if isCoolingDown() {
            currentTick += moment.delta
        }
    }
    
    mutating public func resetCooldown() {
        currentTick = 0
    }
    
    public func copyForEntity(_ entity:Entity) -> Item {
        
        var newItemAbility = Item(ability: ability, conditional: conditional)
        newItemAbility.entity = entity
        return newItemAbility
    }
    
}

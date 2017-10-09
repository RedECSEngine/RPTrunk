
public struct EventResult {
    public let event:Event
    public let effects:[ConflictResult]
    
    init(_ event:Event, _ effects:[ConflictResult]) {
        self.event = event
        self.effects = effects
    }
}

public struct Event {
    
    public let id = UUID().uuidString
    public let ability:Ability
    weak public private(set) var initiator: Entity!
    
    public var targets: [Entity] = []
    
    public init(initiator: Entity, ability: Ability, battle: Battle) {
        self.initiator = initiator
        self.ability = ability
        self.targets = ability.targeting.getValidTargets(for: initiator, in: battle)
    }
    
    func getStats() -> Stats {
        return ability.stats
    }
    
    func getCost() -> Stats {
        return ability.cost * -1
    }
    
    func applyStatusEffectChanges() {
        
        ability.dischargedStatusEffects
            .forEach {
                name in
                targets.forEach { $0.dischargeStatusEffect(name) }
            }
        
        ability.statusEffects
            .forEach {
                se in
                targets.forEach { $0.applyStatusEffect(se) }
        }
    }
    
    //MARK: - Results calculation and application
    
    public func getResults() -> [ConflictResult] {
        let totalStats = getStats()
        let results = targets.map { (target) -> ConflictResult in
            return RPGameEnvironment.current.delegate.resolveConflict(self, target:target, conflict: totalStats)
        }
        let costResult = RPGameEnvironment.current.delegate.resolveConflict(self, target:initiator, conflict: getCost())
        return results + [costResult]
    }
    
    func applyResults(_ results:[ConflictResult]){
        results.forEach { (result) -> () in
            let newStats = result.entity.allCurrentStats() + result.change
            result.entity.setCurrentStats(newStats)
        }
        applyStatusEffectChanges()
    }
    
    public func execute() -> EventResult {
        let results = getResults()
        applyResults(results)
        return EventResult(self, results)
    }
    
}

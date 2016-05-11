
public typealias RPConflictResult = (entity:RPEntity, change:RPStats)

public struct RPEvent {
    public let initiator:RPEntity
    public let ability:Ability
    
    public var targets: [RPEntity] {
        
        //TODO: Iterate over components and potentially modify target selection (i.e 'All' component)
        switch ability.targetType {
        case .Oneself:
            return [initiator]
        case .SingleEnemy:
            return initiator.target != nil ? [initiator.target!] : []
        case .All:
            return initiator.targets
        default:
            return []
        }
    }
    
    public init(initiator:RPEntity, ability:Ability) {
        self.initiator = initiator
        self.ability = ability
    }
    
    func getStats() -> RPStats {
        return ability.stats
    }
    
    func getCost() -> RPStats {
        return ability.cost * -1
    }
    
    func applyBuffs() {
        
        if let a = ability as? RPStatusEffect {
            targets.forEach { $0.statusEffects.append(RPAppliedStatusEffect(a)) }
        } else {
            ability.components
                .flatMap { $0 as? RPStatusEffect
            }
                .forEach {
                    buff in
                    targets.forEach { $0.statusEffects.append(RPAppliedStatusEffect(buff)) }
                }
        }
    }
    
    //MARK: - Results calculation and application
    
    public func getResults() -> [RPConflictResult] {
        let totalStats = getStats()
        let results = targets.map { (target) -> RPConflictResult in
            let result = RPGameEnvironment.current.delegate.resolveConflict(target.stats, b: totalStats)
            return (target, result)
        }
        let costResult = RPGameEnvironment.current.delegate.resolveConflict(initiator.stats, b: getCost())
        return results + [(initiator, costResult)]
    }
    
    func applyResults(results:[RPConflictResult]){
        results.forEach { (result) -> () in
            result.entity.setCurrentStats(result.entity.allCurrentStats() + result.change)
        }
        applyBuffs()
    }
    
    public func execute() -> [RPConflictResult] {
        let results = getResults()
        applyResults(results)
        return results
    }
    
}

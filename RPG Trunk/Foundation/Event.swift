
public typealias ConflictResult = (entity:RPEntity, change:RPStats)

public struct Event {
    let initiator:RPEntity
    let targets:[RPEntity]
    let ability:Ability
    
    public init(initiator:RPEntity, targets:[RPEntity], ability:Ability) {
        self.initiator = initiator
        self.targets = targets
        self.ability = ability
    }
    
    func prepareTargets() {
        //TODO: Iterate over components and potentially modify target selection (i.e 'All' component)
    }
    
    func getStats() -> RPStats {
        return ability.getStats()
    }
    
    func applyBuffs() {
        
        if let a = ability as? Buff {
            targets.forEach { $0.buffs.append(AppliedBuff(a)) }
        } else {
            ability.components
                .flatMap { $0 as? Buff }
                .forEach {
                    buff in
                    targets.forEach { $0.buffs.append(AppliedBuff(buff)) }
                }
        }
    }
    
    //MARK: - Results calculation and application
    
    public func getResults() -> [ConflictResult] {
        prepareTargets()
        let totalStats = getStats()
        let results = targets.map { (target) -> ConflictResult in
            let result = RPGameEnvironment.current.delegate.resolveConflict(target.stats, b: totalStats)
            return (target, result)
        }
        return results
    }
    
    func applyResults(results:[ConflictResult]){
        results.forEach { (result) -> () in
            result.entity.setCurrentStats(result.entity.allCurrentStats() + result.change)
        }
        applyBuffs()
    }
    
    public func execute() -> [ConflictResult] {
        let results = getResults()
        applyResults(results)
        return results
    }
    
}

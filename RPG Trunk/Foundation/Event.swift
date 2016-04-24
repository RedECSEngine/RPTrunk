
public typealias ConflictResult = (entity:RPEntity, change:RPStats)

public struct Event {
    let initiator:RPEntity
    var targets:[RPEntity]
    let ability:Ability
}

public func getResultForEvent(event:Event) -> [ConflictResult] {
    let totalStats = event.initiator.stats + event.ability.stats
    let results = event.targets.map { (target) -> ConflictResult in
        let result = RPGameEnvironment.current.delegate.resolveConflict(target.stats, b: totalStats)
        return (target, result)
    }
   return results
}

public func performEvent(event:Event) -> [ConflictResult] {
    let results = getResultForEvent(event)
    results.forEach { (result) -> () in
        result.entity.setCurrentStats(result.entity.allCurrentStats() + result.change)
    }
    return results
}
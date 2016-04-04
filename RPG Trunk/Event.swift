//
//  Event.swift
//  RPG Trunk
//
//  Created by Kyle Newsome on 2016-01-02.
//  Copyright © 2016 Kyle Newsome. All rights reserved.
//

import Foundation

public typealias ConflictResult = (entity:RPEntity, change:RPStats)

public class Event {
    let initiator:RPEntity
    var targets:[RPEntity]
    let ability:Ability

    public init(initiator:RPEntity, targets:[RPEntity], ability:Ability) {
        self.initiator = initiator
        self.targets = targets
        self.ability = ability
    }
}

public func getResultForEvent(event:Event) -> [ConflictResult] {
    let totalStats = event.initiator.stats + event.ability.stats
    let results = event.targets.map { (target) -> ConflictResult in
        let result = RPGameEnvironment.current.delegate.resolveConflict(target.stats, b: totalStats)
        return (target, result)
    }
   return results
}

public func performEvent(event:Event) {
    getResultForEvent(event).forEach { (result) -> () in
        result.entity.setCurrentStats(result.entity.allCurrentStats() + result.change)
    }
}
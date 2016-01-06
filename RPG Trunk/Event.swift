//
//  Event.swift
//  RPG Trunk
//
//  Created by Kyle Newsome on 2016-01-02.
//  Copyright © 2016 Kyle Newsome. All rights reserved.
//

import Foundation

public typealias ConflictResult = (entity:Entity, change:Stats)

public class Event {
    let initiator:Entity
    var targets:[Entity]
    let ability:Ability

    public init(initiator:Entity, targets:[Entity], ability:Ability) {
        self.initiator = initiator
        self.targets = targets
        self.ability = ability
    }
}

public func getResultForEvent(event:Event) -> [ConflictResult] {
    let totalStats = event.initiator.stats + event.ability.stats
    let results = event.targets.map { (target) -> ConflictResult in
        let result = resolveConflict(target.stats, b: totalStats)
        return (target, result)
    }
   return results
}

public func performEvent(event:Event) {
    getResultForEvent(event).forEach { (result) -> () in
        result.entity.baseStats = result.entity.stats + result.change
    }
}
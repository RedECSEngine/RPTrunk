//
//  Entity.swift
//  RPG Trunk
//
//  Created by Kyle Newsome on 2016-01-02.
//  Copyright © 2016 Kyle Newsome. All rights reserved.
//

import Foundation

public class Body {
    let weapons:[Weapon] = []
    let equipment:[Armor] = []
    let storage = Storage()
}

public class Entity: StatsContainer {
    public var baseStats:Stats = Stats([:])
    
    public var body = Body()
    public var executableAbilities:[Ability] = []
    public var passiveAbilities:[Ability] = []
    public var priorities:[Priority] = []
    
    public var stats:Stats {
        var totalStats = self.baseStats
        for weapon in self.body.weapons {
            totalStats = totalStats + weapon.stats;
        }
        for equip in self.body.equipment {
            totalStats = totalStats + equip.stats;
        }
        return totalStats
    }
    
    public weak var target:Entity?
    
    public init(_ data:Stats) {
        self.baseStats = data
    }
    
    public func getStat(key:String) -> Int {
        return self.stats.hp //TODO: fix this to be dynamic
    }
    
    public func think() -> Event? {
        for priority in self.priorities {
            if priority.evaluate(self) {
                if let target = self.target {
                    return Event(initiator: self, targets: [target], ability: priority.ability)
                }
            }
        }
        return nil
    }
    
    func eventWillOccur(event:Event) {
        
    }

    func eventDidOccur(event:Event) {
    
    }
}

public func getStat(entity:Entity, _ key:String) -> () -> Int {
    return { entity.getStat(key) }
}

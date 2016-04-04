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

public class RPEntity: StatsContainer {
    public private(set) var baseStats = RPStats([:])
    public private(set) var currentStats = RPStats([:], asPartial: true) //when a current is nil, it means it's at max
    
    public var body = Body()
    public var executableAbilities:[Ability] = []
    public var passiveAbilities:[Ability] = []
    public var priorities:[Priority] = []
    public var buffs: [Buff] = []
    
    public weak var target:RPEntity?
    
    public var stats:RPStats {
        var totalStats = self.baseStats
        for weapon in self.body.weapons {
            totalStats = totalStats + weapon.stats;
        }
        for equip in self.body.equipment {
            totalStats = totalStats + equip.stats;
        }
        return totalStats
    }
    
    public subscript(index:String) -> RPValue {
        return currentStats.get(index) ?? stats[index]
    }
    
    public func allCurrentStats() -> RPStats {
        var cs:[String:RPValue] = [:]
        let maxStats = stats
        for type in RPGameEnvironment.statTypes {
            cs[type] = currentStats.get(type) ?? maxStats[type]
        }
        return RPStats(cs)
    }
    
    public func setCurrentStats(newStats:RPStats) {
        var cs:[String:RPValue] = [:]
        let maxStats = stats
        for type in RPGameEnvironment.statTypes {
            cs[type] = newStats[type] < maxStats[type] ? newStats[type] : nil
        }
        currentStats = RPStats(cs)
    }
    
    // Stored on the entity for reuse
    public lazy var parser:Parser<String, PropertyResultType> = {
        return valueParser() <|> entityTargetParser(self) <|> entityStatParser(self)
    }()
    
    public init(_ data:[String:RPValue]) {
        self.baseStats = RPStats(data)
    }
    
    public convenience init() {
        self.init([:])
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

extension RPEntity: CustomStringConvertible {
    
    public var description:String {
        var o:[String:String] = [:]
        let maxStats = stats
        for type in RPGameEnvironment.statTypes {
            o[type] = " \(currentStats.get(type) ?? maxStats[type])/\(maxStats[type])"
        }
        return "Entity:\n " + o.description
    }
    
}


//
//  GameDelegate.swift
//  Pods
//
//  Created by Kyle Newsome on 2016-05-11.
//
//

import Foundation

public protocol RPGameDelegate {

    // instance managers
    var statTypes:[String] { get }
    
    var abilityDefaults:[Component] { get }
    
    func createDefaultEntity() -> Entity
    
    func resolveConflict(_ event:Event, target:Entity, conflict:Stats) -> ConflictResult
}

public struct DefaultGame: RPGameDelegate {
    
    public let statTypes:[String] = [
        "hp",
        "mp",
        "damage",
        "agility",
        "magic",
        "defense"
    ]
    
    public var abilityDefaults = [Component]()
    
    public func createDefaultEntity() -> Entity {
        return Entity()
    }
    
    public func resolveConflict(_ event:Event, target:Entity, conflict:Stats) -> ConflictResult {
    
        //hp result - part 1 - damage hits against hp, with defense as reduction
        var hpResult = 0 // + _b.affinities.healing
        hpResult -= (conflict["damage"] > 0) ? (conflict["damage"] - target["defense"]) : 0
        
        let mpResult = 0 - conflict["mp"]
        //for reducing damage if the stat is below 0
        let dmgResult = (conflict["damage"] >= 0) ? 0 : conflict["damage"]
        //for reducing agility if the stat is below 0
        let agilityResult = conflict["agility"] >= 0 ? 0 : conflict["agility"]
        //for reducing defense if state is below 0
        let defenseResult = conflict["defense"] >= 0 ? 0 : conflict["defense"]
        
        return ConflictResult(target, [
            "hp": hpResult,
            "mp": mpResult,
            "damage": dmgResult,
            "agility": agilityResult,
            "magic": 0,
            "defense": defenseResult,
        ])
    }
    
    
}

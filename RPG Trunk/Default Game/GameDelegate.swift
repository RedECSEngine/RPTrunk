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
    var entityDefaults: Entity { get }
    var abilityDefaults:[Component] { get }
    
    func resolveConflict (target: Stats, b: Stats) -> Stats
    
    func shouldStatusEffectDisableEntity(activeStatusEffect:ActiveStatusEffect) -> Bool
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
    
    public var entityDefaults: Entity {
        return Entity()
    }
    
    public var abilityDefaults = [Component]()
    
    public func resolveConflict (target: Stats, b: Stats) -> Stats {
        //hp result - part 1 - damage hits against hp, with defense as reduction
        var hpResult = 0 // + _b.affinities.healing
        hpResult -= (b["damage"] > 0) ? (b["damage"] - target["defense"]) : 0
        
        //hp result - part 2 - magic affinities against hp, with resistances as reduction
        //TODO: resolve_magics_conflict
        //TODO: use magic stat as addition to affinities
        
        let mpResult = 0 - b["mp"]
        //for reducing damage if the stat is below 0
        let dmgResult = (b["damage"] >= 0) ? 0 : b["damage"]
        //for reducing agility if the stat is below 0
        let agilityResult = b["agility"] >= 0 ? 0 : b["agility"]
        //for reducing defense if state is below 0
        let defenseResult = b["defense"] >= 0 ? 0 : b["defense"]
        
        return Stats([
            "hp": hpResult,
            "mp": mpResult,
            "damage": dmgResult,
            "agility": agilityResult,
            "magic": 0,
            "defense": defenseResult,
            //"affinities": Magics(), // TODO: resolve affinities conflict
            //"resistances": Magics()  // TODO: resolve resistances conflict
            ])
    }
    
    public func shouldStatusEffectDisableEntity(activeStatusEffect:ActiveStatusEffect) -> Bool {
        return false
    }
    
}

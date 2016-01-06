//
//  Stats.swift
//  RPG Trunk
//
//  Created by Kyle Newsome on 2016-01-02.
//  Copyright © 2016 Kyle Newsome. All rights reserved.
//

import Foundation

public struct Stats {
    public let hp:Int
    public let mp:Int
    public let damage:Int
    public let agility:Int
    public let magic:Int
    public let defense:Int
    //let affinities = Magics()
    //let resistances = Magics()
    
    public init(_ data:[String:Int]) {
        self.hp = data["hp"] ?? 0
        self.mp = data["mp"] ?? 0
        self.damage = data["damage"] ?? 0
        self.agility = data["agility"] ?? 0
        self.magic = data["magic"] ?? 0
        self.defense = data["defense"] ?? 0
        //self.affinities = Magics(stats_dict["affinities"])
        //self.resistances = Magics(stats_dict["resistances"])
    }
}

public func + (a:Stats, b:Stats) -> Stats {
    let stats = Stats([
        "hp": a.hp + b.hp,
        "mp": a.mp + b.mp,
        "damage": a.damage + b.damage,
        "agility": a.agility + b.agility,
        "magic": a.magic + b.magic,
        "defense": a.defense + b.defense
        //"affinities": add_magics(stats_a.affinities, stats_b.affinities),
        //"resistances": add_magics(stats_a.resistances, stats_b.resistances)
    ])
    return stats
}

public func - (a:Stats, b:Stats) -> Stats {
    let stats = Stats([
        "hp": a.hp - b.hp,
        "mp": a.mp - b.mp,
        "damage": a.damage - b.damage,
        "agility": a.agility - b.agility,
        "magic": a.magic - b.magic,
        "defense": a.defense - b.defense
        //"affinities": add_magics(stats_a.affinities, stats_b.affinities),
        //"resistances": add_magics(stats_a.resistances, stats_b.resistances)
    ])
    return stats
}

public func resolveConflict (target: Stats, b: Stats) -> Stats {
    //hp result - part 1 - damage hits against hp, with defense as reduction
    var hpResult = 0 // + _b.affinities.healing
    hpResult -= (b.damage > 0) ? (b.damage - target.defense) : 0
    
    //hp result - part 2 - magic affinities against hp, with resistances as reduction
    //TODO: resolve_magics_conflict
    //TODO: use magic stat as addition to affinities
    
    let mpResult = 0 - b.mp
    //for reducing damage if the stat is below 0
    let dmgResult = (b.damage >= 0) ? 0 : b.damage
    //for reducing agility if the stat is below 0
    let agilityResult = b.agility >= 0 ? 0 : b.agility
    //for reducing defense if state is below 0
    let defenseResult = b.defense >= 0 ? 0 : b.defense
    
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
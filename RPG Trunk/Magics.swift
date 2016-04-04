//
//  Magics.swift
//  RPG Trunk
//
//  Created by Kyle Newsome on 2016-01-02.
//  Copyright © 2016 Kyle Newsome. All rights reserved.
//

import Foundation

public struct Magics {
    let fire:RPValue
    let water:RPValue
    let earth:RPValue
    let air:RPValue
    let poison:RPValue
    let healing:RPValue
    
    init(_ data:[String:RPValue]) {
        self.fire = data["fire"] ?? 0
        self.water = data["water"] ?? 0
        self.earth = data["earth"] ?? 0
        self.air = data["air"] ?? 0
        self.poison = data["poison"] ?? 0
        self.healing = data["healing"] ?? 0
    }
}

public func + (a: Magics, b: Magics) -> Magics {
    let magics = Magics([
        "fire": a.fire + b.fire,
        "water": a.water + b.water,
        "earth": a.earth + b.earth,
        "air": a.air + b.air,
        "poison": a.poison + b.poison,
        "healing": a.healing + b.healing
    ])
    return magics
}

public func - (a:Magics,b:Magics) -> Magics {
    let magics = Magics([
        "fire": a.fire - b.fire,
        "water": a.water - b.water,
        "earth": a.earth - b.earth,
        "air": a.air - b.air,
        "poison": a.poison - b.poison,
        "healing": a.healing - b.healing
    ])
    return magics
}
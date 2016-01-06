//
//  Core.swift
//  RPG Trunk
//
//  Created by Kyle Newsome on 2016-01-02.
//  Copyright © 2016 Kyle Newsome. All rights reserved.
//

import Foundation

public protocol StatsContainer {
    var stats:Stats {get}
}

public enum EventTargetType:Int {
    case Oneself = 1
    case All
    case Random
    case AllFriendly
    case AllEnemy
    case GroupFriendly
    case GroupEnemy
    case SingleFriendly
    case SingleEnemy
    case RandomFriendly
    case RandomEnemy
}

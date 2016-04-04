//
//  Stats.swift
//  RPG Trunk
//
//  Created by Kyle Newsome on 2016-01-02.
//  Copyright © 2016 Kyle Newsome. All rights reserved.
//

import Foundation

public struct RPStats {
    
    private let values:[String:RPValue]
    //let affinities = Magics()
    //let resistances = Magics()
    
    public init(_ data:[String:RPValue], asPartial:Bool = false) {
        var stats:[String:RPValue] = [:]
        for type in RPGameEnvironment.statTypes {
            stats[type] = data[type] ?? (asPartial ? nil : 0) //either set it, initialize to 0 or set as nil, if asP
        }
        values = stats
    }
    
    public subscript(index:String) -> RPValue {
        return values[index] ?? 0
    }
    
    public func get(key:String) -> RPValue? {
        return values[key]
    }
}

public func + (a:RPStats, b:RPStats) -> RPStats {
    var dict:[String:RPValue] = [:]
    for type in RPGameEnvironment.statTypes {
        dict[type] = a[type] + b[type]
    }
    return RPStats(dict)
}

public func - (a:RPStats, b:RPStats) -> RPStats {
    var dict:[String:RPValue] = [:]
    for type in RPGameEnvironment.statTypes {
        dict[type] = a[type] - b[type]
    }
    return RPStats(dict)
}

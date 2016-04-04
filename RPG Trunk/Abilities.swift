//
//  Abilities.swift
//  RPG Trunk
//
//  Created by Kyle Newsome on 2016-01-02.
//  Copyright © 2016 Kyle Newsome. All rights reserved.
//

import Foundation

public class Ability: StatsContainer {
    public var name = "Ability"
    public var components:[Component] = []
    public var targetType:EventTargetType = .Oneself  // RPGEventTargetType

    public init(_ data:[String: AnyObject]) {
        self.name = data["name"] as? String ?? "Ability"
        self.components = data["components"] as? [Component] ?? []
    }
    
    public var stats:RPStats {
        return self.components.reduce(RPStats([:]), combine:combineComponentStatsToTotal)
    }
}

public func combineComponentStatsToTotal(total:RPStats, component:Component) -> RPStats {
    return total + component.stats
}
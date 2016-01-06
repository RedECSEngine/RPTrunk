//
//  Abilities.swift
//  RPG Trunk
//
//  Created by Kyle Newsome on 2016-01-02.
//  Copyright © 2016 Kyle Newsome. All rights reserved.
//

import Foundation

public class Ability: StatsContainer {
    var name = "Ability"
    var components:[Component] = []
    var targetType:EventTargetType = .Oneself  // RPGEventTargetType

    public init(_ data:[String: AnyObject]) {
        self.name = data["name"] as? String ?? "Ability"
        self.components = data["components"] as? [Component] ?? []
    }
    
    public var stats:Stats {
        return self.components.reduce(Stats([:]), combine:combineComponentStatsToTotal)
    }
}

public func combineComponentStatsToTotal(total:Stats, component:Component) -> Stats {
    return total + component.stats
}
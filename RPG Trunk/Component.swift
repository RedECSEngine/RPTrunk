//
//  Component.swift
//  RPG Trunk
//
//  Created by Kyle Newsome on 2016-01-02.
//  Copyright © 2016 Kyle Newsome. All rights reserved.
//

import Foundation

public class Component {
    let stats:RPStats
    public init(_ data:[String:RPValue]) {
        self.stats = RPStats(data)
    }
}


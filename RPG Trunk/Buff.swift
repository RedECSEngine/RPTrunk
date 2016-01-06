//
//  Buff.swift
//  RPG Trunk
//
//  Created by Kyle Newsome on 2016-01-02.
//  Copyright © 2016 Kyle Newsome. All rights reserved.
//

import Foundation

public class Buff {
    let event:Event?
    let maxTime = 1
    var currentTime = 0
    
    init() {
        self.event = nil
    }
}
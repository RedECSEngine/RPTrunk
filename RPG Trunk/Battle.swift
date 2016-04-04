//
//  Battle.swift
//  RPG Trunk
//
//  Created by Kyle Newsome on 2016-01-02.
//  Copyright © 2016 Kyle Newsome. All rights reserved.
//

import Foundation

public class RPBattle {
    
    public var entities:[RPEntity] = []
    public var queue:[Event] = []
    
    public init () {
    
    }
    
    public func addEvent(event:Event) {
        self.queue += [event]
    }
    
    public func tick() {
        for entity in self.entities {
            if let resultingEvent = entity.think() {
                self.addEvent(resultingEvent)
            }
        }
        for event in self.queue {
            for entity in self.entities {
                entity.eventWillOccur(event)
            }
            performEvent(event)
            for entity in self.entities {
                entity.eventDidOccur(event)
            }
        }
        self.queue = []
    }
    
    
}

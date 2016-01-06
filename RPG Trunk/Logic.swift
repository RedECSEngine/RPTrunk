//
//  Logic.swift
//  RPG Trunk
//
//  Created by Kyle Newsome on 2016-01-02.
//  Copyright © 2016 Kyle Newsome. All rights reserved.
//

import Foundation

public struct Priority {
    public let ability:Ability  // Executable Ability
    public let conditionals:[Conditional]? //Conditions, if none then this priority will always validate
    
    public init (ability:Ability, conditionals:[Conditional]?) {
        self.ability = ability
        self.conditionals = conditionals
    }
    
    public func evaluate(entity:Entity) -> Bool {
        guard let _ = self.conditionals else {
            return true; //this priority always passes if it has no conditions
        }
        return checkConditionals(self.conditionals!)
    }
    
}
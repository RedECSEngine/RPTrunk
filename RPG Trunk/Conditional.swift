//
//  Condition.swift
//  RPG Trunk
//
//  Created by Kyle Newsome on 2016-01-02.
//  Copyright © 2016 Kyle Newsome. All rights reserved.
//

import Foundation

public typealias Conditional = () -> Bool

/**:
    
**Params**
- lhs : A function that returns a value
- rhs: A function that takes a value of the same type as `lhs` and returns a Bool

**Example:** buildConditional(getStat(joe, "hp"), isGreaterThan(20))

*/
public func buildConditional<U>(lhs:() -> U, _ rhs:U -> Bool) -> Conditional {
    return { () -> Bool in
        return rhs(lhs())
    }
}

public func checkConditionals(conditionals:[Conditional]) -> Bool {
    let result = conditionals.reduce([]) { (failures, condition) -> [String] in
        if !condition() {
            return failures + ["Condition failed"]
        }
        return failures
    }
    return result.count == 0;
}

public func isGreaterThan<U:Comparable>(rhs:U)(_ lhs:U) -> Bool {
    return lhs > rhs
}

public func isLessThan<U:Comparable>(rhs:U)(_ lhs:U) -> Bool {
    return lhs < rhs;
}

public func isEqual<U:Comparable>(rhs:U)(lhs:U) -> Bool {
    return lhs == rhs;
}
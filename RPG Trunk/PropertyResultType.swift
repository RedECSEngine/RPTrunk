
import Foundation

public enum PropertyResultType {
    case Entity(entity:RPEntity)
    case Stats(stats:RPStats)
    case Value(value:RPValue)
    case Nothing
}

public func ==(a: PropertyResultType, b: PropertyResultType) -> Bool {
    
    switch (a, b) {
    case (.Entity(let a), .Entity(let b)) where a === b: return true
    case (.Value(let a), .Value(let b)) where a == b: return true
    case (.Nothing, .Nothing): return true
    default: return false
    }
}
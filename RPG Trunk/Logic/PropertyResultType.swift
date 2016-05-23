
public enum PropertyResultType {
    
    case EntityResult(entity:Entity)
    case StatsResult(stats:Stats)
    case ValueResult(value:RPValue)
    case BoolResult(value:Bool)
    case Nothing
}

public func ==(a: PropertyResultType, b: PropertyResultType) -> Bool {
    
    switch (a, b) {
    case (.EntityResult(let a), .EntityResult(let b)) where a === b: return true
    case (.ValueResult(let a), .ValueResult(let b)) where a == b: return true
    case (.BoolResult(let a), .BoolResult(let b)) where a == b: return true
    case (.StatsResult(let a), .StatsResult(let b)) where a == b: return true
    case (.Nothing, .Nothing): return true
    default:
        return false
    }
}
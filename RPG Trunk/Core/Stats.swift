
public struct RPStats: SequenceType {
    
    public typealias Generator = DictionaryGenerator<String, RPValue>
    
    private let values:[String:RPValue]
    
    public init(_ data:[String:RPValue], asPartial:Bool = false) {
        var stats:[String:RPValue] = [:]
        for type in RPGameEnvironment.statTypes {
            stats[type] = data[type] ?? (asPartial ? nil : 0) //either set it, initialize to 0 or set as nil, if asP
        }
        values = stats
    }
    
    public init() {
        values = [:]
    }
    
    public subscript(index:String) -> RPValue {
        return values[index] ?? 0
    }
    
    public func get(key:String) -> RPValue? {
        return values[key]
    }
    
    public func nonZeroes() -> RPStats {
        
        var changes = [String:RPValue]()
        values.forEach { (key, val) in
            if val != 0 {
                changes[key] = val
            }
        }
        return RPStats(changes, asPartial: true)
    }
    
    public func generate() -> RPStats.Generator {
        return values.generate()
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

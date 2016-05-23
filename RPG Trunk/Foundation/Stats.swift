
public struct Stats: Component {
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
    
    public func nonZeroes() -> Stats {
        
        var changes = [String:RPValue]()
        values.forEach { (key, val) in
            if val != 0 {
                changes[key] = val
            }
        }
        return Stats(changes, asPartial: true)
    }
    
    public func getStats() -> Stats? {
        return self
    }
}

extension Stats: SequenceType {

    public typealias Generator = DictionaryGenerator<String, RPValue>
    
    public func generate() -> Stats.Generator {
        return values.generate()
    }
}

extension Stats: DictionaryLiteralConvertible {
    
    public init(dictionaryLiteral elements: (String, RPValue)...) {
        values = elements.reduce([:]) {
            prev, current in
            var new = prev
            new[current.0] = current.1
            return new
        }
    }
}

extension Stats: Comparable {}

public func == (a: Stats, b: Stats) -> Bool {
    for type in RPGameEnvironment.statTypes where a[type] != b[type] {
        return false
    }
    return true
}

public func < (a: Stats, b: Stats) -> Bool {
    
    for (type, value) in b.values where a[type] < value {
        return true
    }
    
    return false
}


//MARK: Other math functions

public func + (a: Stats, b: Stats) -> Stats {
    var dict:[String:RPValue] = [:]
    for (type, val) in b.values {
        dict[type] = a[type] + val
    }
    return Stats(dict)
}

public func - (a: Stats, b: Stats) -> Stats {
    var dict:[String:RPValue] = [:]
    for (type, val) in b.values {
        dict[type] = a[type] - val
    }
    return Stats(dict)
}

public func * (a: Stats, b: Stats) -> Stats {
    var dict:[String:RPValue] = [:]
    for (type, val) in b.values {
        dict[type] = a[type] * val
    }
    return Stats(dict)
}

public func * (a: Stats, amount: Int) -> Stats {
    var dict:[String:RPValue] = [:]
    for (type, val) in a.values {
        dict[type] = val * amount
    }
    return Stats(dict)
}

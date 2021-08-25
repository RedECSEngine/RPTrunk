
public protocol StatsType: Numeric, Comparable, Codable {
    /// all stored properties should have default values
    init()
    
    init(dict: [String: Int])
    
    subscript(index: String) -> Int { get set }
    
    /// all keypath that are read/writable from a string. This is what the parser can interpret and can include computed properties
    static var dynamicKeys: [String: WritableKeyPath<Self, Int>] { get }
    
    /// keypaths to be used in arithmetic and comparison. This should include all stored properties, as new copies are made during arithmetic
    static var numericAndComparableKeys: [WritableKeyPath<Self, Int>] { get }
}

extension StatsType {
    public init(dict: [String : Int]) {
        self = .zero
        for (key, value) in dict {
            self[key] = value
        }
    }
    
    public init(dict: [WritableKeyPath<Self, Int>: Int]) {
        self = .zero
        for (keyPath, value) in dict {
            self[keyPath: keyPath] = value
        }
    }
    
    public subscript(index: String) -> Int {
        get { self.get(key: index) }
        set(newValue) { self.set(key: index, value: newValue) }
    }
    
    mutating func set(key: String, value: Int) {
        if let keyPath = Self.dynamicKeys[key] {
            self[keyPath: keyPath] = value
        }
    }
    
    func get(key: String) -> Int {
        if let keyPath = Self.dynamicKeys[key] {
            return self[keyPath: keyPath]
        }
        return 0
    }
    
    public init(integerLiteral value: Int) {
        self = .init()
        for keyPath in Self.numericAndComparableKeys {
            self[keyPath: keyPath] = value
        }
    }
    
    public init?<T>(exactly source: T) where T : BinaryInteger {
        self = .init(integerLiteral: Int(source))
    }
    
    public var magnitude: Self {
        var stats = Self.zero
        for keyPath in Self.numericAndComparableKeys {
            stats[keyPath: keyPath] = abs(stats[keyPath: keyPath])
        }
        return stats
    }
    
    public static func < (lhs: Self, rhs: Self) -> Bool {
        for keyPath in numericAndComparableKeys {
            if lhs[keyPath: keyPath] < rhs[keyPath: keyPath] {
                return true
            }
        }
        return false
    }
    
    public static func * (lhs: Self, rhs: Self) -> Self {
        var stats = Self.zero
        for keyPath in numericAndComparableKeys {
            stats[keyPath: keyPath] = lhs[keyPath: keyPath] * rhs[keyPath: keyPath]
        }
        return stats
    }
    
    public static func *= (lhs: inout Self, rhs: Self) {
        lhs = lhs * rhs
    }
    
    public static func - (lhs: Self, rhs: Self) -> Self {
        var stats = Self.zero
        for keyPath in numericAndComparableKeys {
            stats[keyPath: keyPath] = lhs[keyPath: keyPath] - rhs[keyPath: keyPath]
        }
        return stats
    }

    public static func + (lhs: Self, rhs: Self) -> Self {
        var stats = Self.zero
        for keyPath in numericAndComparableKeys {
            stats[keyPath: keyPath] = lhs[keyPath: keyPath] + rhs[keyPath: keyPath]
        }
        return stats
    }
}

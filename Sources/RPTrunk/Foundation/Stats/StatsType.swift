
public protocol StatsType: Numeric, Comparable, Codable, CustomStringConvertible {
    /// all stored properties should have default values
    init()

    init(dict: [String: Int])

    subscript(index: String) -> Int { get set }

    /// all keypath that are read/writable from a string. This is what the parser can interpret and can include computed properties
    static var dynamicKeys: [String: WritableKeyPath<Self, Int>] { get }
}

extension StatsType {
    public var description: String {
        Self.dynamicKeys.keys.compactMap { key in
            let value = self[key]
            guard value != 0 else {
                return nil
            }
            return "\(key):" + String(self[key])
        }.joined(separator: "\n")
    }
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
}

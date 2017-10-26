
public struct Identity {
    
    public let name: String
    public let labels: [String]
    
    public init(name: String) {
        self.name = name
        self.labels = []
    }
    
    public init(name: String, labels: [String]) {
        self.name = name
        self.labels = labels
    }
    
}

extension Identity: Equatable {}

public func ==(lhs: Identity, rhs: Identity) -> Bool {
    return lhs.name == rhs.name
        && lhs.labels == rhs.labels
}


extension Identity: ExpressibleByStringLiteral {
    
    public typealias ExtendedGraphemeClusterLiteralType = StringLiteralType
    public typealias UnicodeScalarLiteralType = Character
    
    public init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self.init(name: "\(value)")
    }
    
    public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        self.init(name: value)
    }
    
    public init(stringLiteral value: StringLiteralType) {
        self.init(name: value)
    }
}

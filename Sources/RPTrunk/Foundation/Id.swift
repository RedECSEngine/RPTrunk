import Foundation

public struct Id<T: Codable>: RawRepresentable {
    public let rawValue: String
    public init?(rawValue: String) {
        self.rawValue = rawValue
    }
    public init() {
        self.rawValue = UUID().uuidString
    }
    public init(value: String) {
        self.rawValue = value
    }
}
    
extension Id: Hashable {
    public var hashValue: Int { rawValue.hashValue }
}

extension Id: Equatable {}

extension Id: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public init(stringLiteral: StringLiteralType) {
        self.rawValue = stringLiteral
    }
}

extension Id: CustomStringConvertible {
    public var description: String { rawValue }
}

extension Id: Codable {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }
   
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

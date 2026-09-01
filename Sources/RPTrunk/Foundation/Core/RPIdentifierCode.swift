/// A named string code. Each conformer is a distinct type, so an equipment
/// slot code cannot be passed where an ability code is expected in game code when constants are used
///
public protocol RPIdentifierCode: Hashable,
                        Comparable,
                        Codable,
                        CodingKeyRepresentable,
                        ExpressibleByStringLiteral,
                        CustomStringConvertible,
                        Sendable {
    var rawValue: String { get }
    init(_ rawValue: String)
}

public extension RPIdentifierCode {
    init(stringLiteral value: String) {
        self.init(value)
    }

    var description: String { rawValue }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var codingKey: CodingKey {
        RPIdentifierCodeCodingKey(stringValue: rawValue)
    }

    init?<Key: CodingKey>(codingKey: Key) {
        self.init(codingKey.stringValue)
    }
}

/// Lets a code type key a dictionary that still encodes as a JSON object
/// (`{"trinket": 2}`) rather than the flat key/value array `Codable` falls back
/// to for non-string keys.
public struct RPIdentifierCodeCodingKey: CodingKey {
    public let stringValue: String
    public let intValue: Int? = nil

    public init(stringValue: String) {
        self.stringValue = stringValue
    }

    public init?(intValue: Int) {
        nil
    }
}


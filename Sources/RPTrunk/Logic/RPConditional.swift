
public enum RPConditional<RP: RPSpace>: Codable {
    private enum CodingKeys: String, CodingKey {
        case rawValue
    }

    public typealias Predicate = (RPConditionContext, RP) throws -> Bool

    case always
    case never
    case custom(String, Predicate)

    public static func fromString(_ condition: String) -> Self {
        guard condition != "always" else {
            return .always
        }
        guard condition != "never" else {
            return .never
        }

        do {
            return try buildConditionalFromString(condition)
        } catch {
            print("WARNING: Failed to parse conditional (\(condition)). Will NEVER fire", error)
            return .never
        }
    }

    public init(_ condition: String) {
        self = RPConditional.fromString(condition)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try values.decode(String.self, forKey: .rawValue)
        self.init(rawValue)
    }

    public func toString() -> String {
        switch self {
        case .always: return "always"
        case .never: return "never"
        case let .custom(predicateAsString, _):
            return predicateAsString
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(toString(), forKey: .rawValue)
    }

    public func exec(_ e: RPBody<RP>, initiator: RPBodyId? = nil, rpSpace: RP) throws -> Bool {
        switch self {
        case .always:
            return true
        case .never:
            return false
        case let .custom(_, query):
            return try query(RPConditionContext(body: e.id, initiator: initiator ?? e.id), rpSpace)
        }
    }
}

extension RPConditional: CustomStringConvertible {
    public var description: String {
        switch self {
        case .always:
            return "Always"
        case .never:
            return "Never"
        case let .custom(condition, _):
            return condition
        }
    }
}

extension RPConditional: Equatable {}

public func ==<RP: RPSpace> (
    lhs: RPConditional<RP>,
    rhs: RPConditional<RP>
) -> Bool {
    lhs.description == rhs.description
}

extension RPConditional: ExpressibleByStringLiteral {
    public typealias ExtendedGraphemeClusterLiteralType = StringLiteralType
    public typealias UnicodeScalarLiteralType = Character

    public init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self.init("\(value)")
    }

    public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        self.init(value)
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
}

func buildConditionalFromString<RP: RPSpace>(_ conditionString: String) throws -> RPConditional<RP> {
    // `&&` conjunctions are handled by the grammar itself.
    .custom(conditionString, try interpretStringCondition(conditionString))
}

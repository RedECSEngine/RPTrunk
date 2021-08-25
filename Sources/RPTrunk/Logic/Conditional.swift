import Parsing

public enum Conditional<RP: RPSpace>: Codable {
    private enum CodingKeys: String, CodingKey {
        case rawValue
    }

    public typealias Predicate = (RPEntityId, RP) throws -> Bool

    case always
    case never
    case custom(String, Predicate)

    public static func fromString(_ condition: String) -> Self {
        guard condition != "always" else {
            return .always
        }

        do {
            return try buildConditionalFromString(condition)
        } catch {
            print("WARNING: Failed to parse conditional (\(condition)). Will NEVER fire", error)
            return .never
        }
    }

    public init(_ condition: String) {
        self = Conditional.fromString(condition)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try values.decode(String.self, forKey: .rawValue)
        self.init(rawValue)
    }

    public func toString() -> String {
        switch self {
        case .always: return "always"
        case .never: return ""
        case let .custom(predicateAsString, _):
            return predicateAsString
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(toString(), forKey: .rawValue)
    }

    public func exec(_ e: RPEntity<RP>, rpSpace: RP) throws -> Bool {
        switch self {
        case .always:
            return true
        case .never:
            return false
        case let .custom(_, query):
            return try query(e.id, rpSpace)
        }
    }
}

extension Conditional: CustomStringConvertible {
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

extension Conditional: Equatable {}

public func ==<RP: RPSpace> (
    lhs: Conditional<RP>,
    rhs: Conditional<RP>
) -> Bool {
    lhs.description == rhs.description
}

extension Conditional: ExpressibleByStringLiteral {
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

enum ConditionalInterpretationError: Error {
    case invalidSyntax(reason: String)
    case cantCompareValues
}

func buildConditionalFromString<RP: RPSpace>(_ conditionString: String) throws -> Conditional<RP> {
    let statements = conditionString.components(separatedBy: " && ")
    if statements.count == 1 {
        return .custom(conditionString, try interpretStringCondition(statements[0]))
    } else {
        var predicates = [Conditional<RP>.Predicate]()
        try statements.forEach {
            statement in
            try predicates.append(interpretStringCondition(statement))
        }

        let finalPredicate: Conditional<RP>.Predicate = {
            entity, rpSpace in
            // iterate over all predicates and confirm that none are 'false'
            try predicates.contains(where: { predicate -> Bool in
                try !predicate(entity, rpSpace)
            }) == false
        }
        return .custom(conditionString, finalPredicate)
    }
}

func interpretStringCondition<RP: RPSpace>(_ condition: String) throws -> Conditional<RP>.Predicate {
    if let (lhs, op, rhs): ([ParserResultType<RP>], ConditionalOperator, [ParserResultType<RP>]) = buildParser().parse(condition) {
        return { entity, rpSpace -> Bool in
            let lhsResult = extractValue(entity, evaluators: lhs, in: rpSpace)
            let rhsResult = extractValue(entity, evaluators: rhs, in: rpSpace)
            guard let l = lhsResult, let r = rhsResult else {
                return false
            }
            guard l.canCompare(to: r) else {
                throw ConditionalInterpretationError.cantCompareValues
            }
            return op.evaluate(l, r)
        }
    } else if let statusInquiry: ParserResultType<RP> = buildStatusParser().parse(condition) {
        return { entity, rpSpace -> Bool in
            return extractValue(entity, evaluators: [statusInquiry], in: rpSpace) == .bool(true)
        }
    } else {
        throw ConditionalInterpretationError.invalidSyntax(reason: "Could not parse")
    }
}

func extractValue<RP: RPSpace>(
    _ entity: RPEntityId,
    evaluators: [ParserResultType<RP>],
    in rpSpace: RP
) -> ParserValueType? {
    let initial = ParserResultType<RP>.entityResult(entity: entity)
    
    let final = evaluators.reduce(initial, {
        prev, current -> ParserResultType<RP> in

        if case let .evaluationFunction(f) = current {
            return f(prev, rpSpace)
        }

        return current
    })
    
    switch final {
    case let .valueResult(v):
        return v
    default:
        return nil
    }
}

public func extractValue<RP: RPSpace>(
    _ entity: RPEntityId,
    evaluate evaluationString: String,
    in rpSpace: RP
) -> ParserValueType? {
    let dotNotationParser: AnyParser<Substring, [ParserResultType<RP>]>  = buildDotNotationParser()
    guard let evaluationResult = dotNotationParser.parse(evaluationString) else {
        return nil
    }
    return extractValue(entity, evaluators: evaluationResult, in: rpSpace)
}

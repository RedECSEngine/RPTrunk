
public enum Conditional: Codable {
    private enum CodingKeys: String, CodingKey {
        case rawValue
    }

    public typealias Predicate = (Entity) throws -> Bool

    case always
    case never
    case custom(String, Predicate)

    public static func fromString(_ condition: String) -> Conditional {
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

    public func exec(_ e: Entity) throws -> Bool {
        switch self {
        case .always:
            return true
        case .never:
            return false
        case let .custom(_, query):
            return try query(e)
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

public func == (lhs: Conditional, rhs: Conditional) -> Bool {
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

//private extension Conditional {
//    init(_ condition: String, _ predicate: @escaping (Entity) -> Bool) {
//        self = .custom(condition, predicate)
//    }
//}

//public func && (a: Conditional, b: Conditional) -> Conditional {
//    let condition = a.description + " && " + b.description
//    return Conditional(condition) { e in
//        a.exec(e) && b.exec(e)
//    }
//}
//
//public func || (a: Conditional, b: Conditional) -> Conditional {
//    let condition = a.description + " || " + b.description
//    return Conditional(condition) { e in
//        a.exec(e) || b.exec(e)
//    }
//}

// MARK: - Internal access types & functions
//
//enum ConditionalQueryType: Int {
//    case comparison = 3
//    case examination = 1
//}

enum ConditionalInterpretationError: Error {
    case invalidSyntax(reason: String)
    case cantCompareValues
}

func buildConditionalFromString(_ conditionString: String) throws -> Conditional {
    let statements = conditionString.components(separatedBy: " && ")
    if statements.count == 1 {
        let predicate = try interpretStringCondition(statements[0])
        return .custom(conditionString, predicate)
    } else {
        var predicates = [Conditional.Predicate]()
        try statements.forEach {
            statement in
            try predicates.append(interpretStringCondition(statement))
        }

        let finalPredicate: Conditional.Predicate = {
            entity in
            // iterate over all predicates and confirm that none are 'false'
            try predicates.contains(where: { predicate -> Bool in
                try !predicate(entity)
            }) == false
        }
        return .custom(conditionString, finalPredicate)
    }
}

func interpretStringCondition(_ condition: String) throws -> Conditional.Predicate {
    if let (lhs, op, rhs) = logicalComparisonParser.parse(condition) {
        return { entity -> Bool in
            let lhsResult = extractValue(entity, evaluators: lhs)
            let rhsResult = extractValue(entity, evaluators: rhs)
            guard let l = lhsResult, let r = rhsResult else {
                return false
            }
            guard l.canCompare(to: r) else {
                throw ConditionalInterpretationError.cantCompareValues
            }
            return op.evaluate(l, r)
        }
    } else if let statusInquiry = statusParser.parse(condition) {
        return { entity -> Bool in
            return extractValue(entity, evaluators: [statusInquiry]) == .bool(true)
        }
    } else {
        throw ConditionalInterpretationError.invalidSyntax(reason: "Could not parse")
    }
}

func extractValue(_ entity: Entity, evaluators: [ParserResultType]) -> ParserValueType? {
    let initial = ParserResultType.entityResult(entity: entity)
    
    let final = evaluators.reduce(initial, {
        prev, current -> ParserResultType in

        if case let .evaluationFunction(f) = current {
            return f(prev)
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

public func extractValue(_ entity: Entity, evaluate evaluationString: String) -> ParserValueType? {
    guard let evaluationResult = dotNotationParser
            .parse(evaluationString) else {
        return nil
    }
    return extractValue(entity, evaluators: evaluationResult)
}

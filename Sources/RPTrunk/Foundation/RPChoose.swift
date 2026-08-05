public enum RPChooseDirection: String {
    case lowest
    case highest
}

public enum RPChooseError: Error {
    case malformedDescriptor(String)
    case mixedSelection(String)
}

public struct RPChooseDescriptor<RP: RPSpace> {
    public let operand: ConditionOperand
    public let direction: RPChooseDirection
    let evaluators: [ParserResultType<RP>]

    public init(tokens: [ConditionToken], direction: RPChooseDirection) throws {
        operand = ConditionOperand(tokens: tokens)
        self.direction = direction
        evaluators = try compileOperand(operand)
    }

    public init(_ source: String) throws {
        var trimmed = Substring(source)
        while let first = trimmed.first, first.isWhitespace { trimmed.removeFirst() }
        while let last = trimmed.last, last.isWhitespace { trimmed.removeLast() }
        let parsed: ConditionOperand
        do {
            parsed = try ConditionOperandParser().parse(trimmed)
        } catch {
            throw RPChooseError.malformedDescriptor(source)
        }
        guard parsed.tokens.count >= 2,
              case let .identifier(directionName, usePercent: false)? = parsed.tokens.last,
              let parsedDirection = RPChooseDirection(rawValue: directionName)
        else {
            throw RPChooseError.malformedDescriptor(source)
        }
        try self.init(tokens: Array(parsed.tokens.dropLast()), direction: parsedDirection)
    }

    public func toString() -> String {
        let chain = operand.tokens
            .map(ConditionTokenParser.text(for:))
            .joined(separator: ".")
        return "\(chain).\(direction.rawValue)"
    }
}

extension RPChooseDescriptor: Equatable {
    public static func == (lhs: RPChooseDescriptor, rhs: RPChooseDescriptor) -> Bool {
        lhs.operand == rhs.operand && lhs.direction == rhs.direction
    }
}

public enum RPChoose<RP: RPSpace>: Equatable {
    case random
    case by([RPChooseDescriptor<RP>])

    public static var anyone: RPChoose { .by([]) }

    public static var highestThreat: RPChoose {
        (try? RPChoose.parse("threat.highest")) ?? .by([])
    }

    public static func parse(_ source: String) throws -> RPChoose {
        let parts = source
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { part -> String in
                var trimmed = part
                while let first = trimmed.first, first.isWhitespace { trimmed.removeFirst() }
                while let last = trimmed.last, last.isWhitespace { trimmed.removeLast() }
                return String(trimmed)
            }
        if parts == ["random"] {
            return .random
        }
        if parts == ["any"] {
            return .by([])
        }
        guard !parts.contains("random"), !parts.contains("any") else {
            throw RPChooseError.mixedSelection(source)
        }
        return .by(try parts.map { try RPChooseDescriptor($0) })
    }

    public func toString() -> String {
        switch self {
        case .random:
            return "random"
        case let .by(descriptors) where descriptors.isEmpty:
            return "any"
        case let .by(descriptors):
            return descriptors.map { $0.toString() }.joined(separator: ", ")
        }
    }
}

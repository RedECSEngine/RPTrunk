public struct RPTargetingSortDescriptor<RP: RPSpace> {
    public let operand: ConditionOperand
    public let direction: RPTargetingSortDirection
    let evaluators: [ParserResultType<RP>]

    public init(tokens: [ConditionToken], direction: RPTargetingSortDirection) throws {
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
            throw RPTargetingSortError.malformedDescriptor(source)
        }
        guard parsed.tokens.count >= 2,
              case let .keyword(directionName, usePercent: false)? = parsed.tokens.last,
              let parsedDirection = RPTargetingSortDirection(rawValue: directionName)
        else {
            throw RPTargetingSortError.malformedDescriptor(source)
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

extension RPTargetingSortDescriptor: Equatable {
    public static func == (lhs: RPTargetingSortDescriptor, rhs: RPTargetingSortDescriptor) -> Bool {
        lhs.operand == rhs.operand && lhs.direction == rhs.direction
    }
}

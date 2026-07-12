// MARK: - Parser-printer abstraction

/// Minimal in-house parser-printer contract. The grammar below is small,
/// hand-rolled recursive descent; this is all the machinery it needs.
protocol ConditionParserPrinter {
    associatedtype Output
    /// Consumes as much of `input` as it can; throws when the input does not
    /// match the grammar.
    func parse(_ input: inout Substring) throws -> Output
    /// Renders `output` in canonical form, prepending it to `input`.
    func print(_ output: Output, into input: inout Substring) throws
}

extension ConditionParserPrinter {
    /// Parses the entire input; throws if any characters are left unconsumed.
    func parse(_ input: some StringProtocol) throws -> Output {
        var remainder = Substring(input)
        let output = try parse(&remainder)
        guard remainder.isEmpty else {
            throw ConditionSyntaxError.unexpectedTrailingCharacters(String(remainder))
        }
        return output
    }

    /// Renders `output` in canonical form.
    func print(_ output: Output) throws -> String {
        var input = Substring()
        try print(output, into: &input)
        return String(input)
    }
}

// MARK: - Syntax tree

/// One term in a dot-notation chain, e.g. `target`, `hp%`, `Healing?`, `40`, `10%`, `false`.
public enum ConditionToken: Equatable {
    case target
    case identifier(String, usePercent: Bool)
    case status(String)
    case value(RPValue)
    case percent(Double)
    case bool(Bool)
}

/// A dot-notation chain, e.g. `target.hp%`.
public struct ConditionOperand: Equatable {
    public var tokens: [ConditionToken]

    public init(tokens: [ConditionToken]) {
        self.tokens = tokens
    }
}

public struct ConditionComparison: Equatable {
    public var op: ConditionalOperator
    public var rhs: ConditionOperand

    public init(op: ConditionalOperator, rhs: ConditionOperand) {
        self.op = op
        self.rhs = rhs
    }
}

/// A single clause: either a comparison (`hp > target.hp`) or a bare
/// status query (`Healing?`).
public struct ConditionClause: Equatable {
    public var lhs: ConditionOperand
    public var comparison: ConditionComparison?

    public init(lhs: ConditionOperand, comparison: ConditionComparison? = nil) {
        self.lhs = lhs
        self.comparison = comparison
    }
}

/// A full condition: one or more clauses joined by `&&`.
public struct ParsedCondition: Equatable {
    public var clauses: [ConditionClause]

    public init(clauses: [ConditionClause]) {
        self.clauses = clauses
    }
}

// MARK: - Parser-printers

enum ConditionSyntaxError: Error {
    case expectedToken
    case expectedOperator
    case malformedPercentValue(String)
    case unexpectedTrailingCharacters(String)
}

private func consumeWhitespace(_ input: inout Substring) {
    let spaces = input.prefix(while: \.isWhitespace)
    input.removeFirst(spaces.count)
}

/// Characters that terminate a token: whitespace, chain separators,
/// conjunctions and comparison operators.
private func isTokenTerminator(_ c: Character) -> Bool {
    c.isWhitespace || c == "." || c == "&" || "><=!".contains(c)
}

struct ConditionTokenParser: ConditionParserPrinter {
    func parse(_ input: inout Substring) throws -> ConditionToken {
        let body = input.prefix(while: { !isTokenTerminator($0) })
        guard !body.isEmpty else {
            throw ConditionSyntaxError.expectedToken
        }
        input.removeFirst(body.count)
        return try Self.classify(String(body))
    }

    func print(_ output: ConditionToken, into input: inout Substring) throws {
        input.insert(contentsOf: Self.text(for: output), at: input.startIndex)
    }

    static func classify(_ body: String) throws -> ConditionToken {
        if body == "true" { return .bool(true) }
        if body == "false" { return .bool(false) }
        if body == "target" { return .target }
        if let value = RPValue(body) {
            return .value(value)
        }
        if body.hasSuffix("?") {
            return .status(String(body.dropLast()))
        }
        if body.hasSuffix("%") {
            let stem = String(body.dropLast())
            if let percent = Double(stem) {
                return .percent(percent)
            }
            guard !stem.isEmpty, Double(stem) == nil else {
                throw ConditionSyntaxError.malformedPercentValue(body)
            }
            return .identifier(stem, usePercent: true)
        }
        return .identifier(body, usePercent: false)
    }

    static func text(for token: ConditionToken) -> String {
        switch token {
        case .target:
            return "target"
        case let .identifier(name, usePercent):
            return usePercent ? "\(name)%" : name
        case let .status(name):
            return "\(name)?"
        case let .value(value):
            return "\(value)"
        case let .percent(value):
            return "\(value.formattedAsConditionPercent)%"
        case let .bool(value):
            return "\(value)"
        }
    }
}

struct ConditionOperandParser: ConditionParserPrinter {
    func parse(_ input: inout Substring) throws -> ConditionOperand {
        var tokens = [try ConditionTokenParser().parse(&input)]
        while input.first == "." {
            input.removeFirst()
            tokens.append(try ConditionTokenParser().parse(&input))
        }
        return ConditionOperand(tokens: tokens)
    }

    func print(_ output: ConditionOperand, into input: inout Substring) throws {
        let text = output.tokens
            .map(ConditionTokenParser.text(for:))
            .joined(separator: ".")
        input.insert(contentsOf: text, at: input.startIndex)
    }
}

struct ConditionOperatorParser: ConditionParserPrinter {
    func parse(_ input: inout Substring) throws -> ConditionalOperator {
        let body = input.prefix(while: { "><=!".contains($0) })
        guard let op = ConditionalOperator(rawValue: String(body)) else {
            throw ConditionSyntaxError.expectedOperator
        }
        input.removeFirst(body.count)
        return op
    }

    func print(_ output: ConditionalOperator, into input: inout Substring) throws {
        input.insert(contentsOf: output.rawValue, at: input.startIndex)
    }
}

struct ConditionClauseParser: ConditionParserPrinter {
    func parse(_ input: inout Substring) throws -> ConditionClause {
        consumeWhitespace(&input)
        let lhs = try ConditionOperandParser().parse(&input)
        consumeWhitespace(&input)

        let checkpoint = input
        if let op = try? ConditionOperatorParser().parse(&input) {
            consumeWhitespace(&input)
            let rhs = try ConditionOperandParser().parse(&input)
            consumeWhitespace(&input)
            return ConditionClause(lhs: lhs, comparison: .init(op: op, rhs: rhs))
        }
        input = checkpoint
        return ConditionClause(lhs: lhs, comparison: nil)
    }

    func print(_ output: ConditionClause, into input: inout Substring) throws {
        var text = ""
        var lhsInput = Substring()
        try ConditionOperandParser().print(output.lhs, into: &lhsInput)
        text += lhsInput
        if let comparison = output.comparison {
            var rhsInput = Substring()
            try ConditionOperandParser().print(comparison.rhs, into: &rhsInput)
            text += " \(comparison.op.rawValue) \(rhsInput)"
        }
        input.insert(contentsOf: text, at: input.startIndex)
    }
}

struct ConditionParser: ConditionParserPrinter {
    func parse(_ input: inout Substring) throws -> ParsedCondition {
        var clauses = [try ConditionClauseParser().parse(&input)]
        while input.hasPrefix("&&") {
            input.removeFirst(2)
            clauses.append(try ConditionClauseParser().parse(&input))
        }
        return ParsedCondition(clauses: clauses)
    }

    func print(_ output: ParsedCondition, into input: inout Substring) throws {
        var texts: [String] = []
        for clause in output.clauses {
            var clauseInput = Substring()
            try ConditionClauseParser().print(clause, into: &clauseInput)
            texts.append(String(clauseInput))
        }
        input.insert(contentsOf: texts.joined(separator: " && "), at: input.startIndex)
    }
}

// MARK: - Entry points

public func parseCondition(_ condition: String) throws -> ParsedCondition {
    try ConditionParser().parse(condition)
}

/// Renders a parsed condition back to its canonical string form.
public func printCondition(_ condition: ParsedCondition) throws -> String {
    var input = Substring()
    try ConditionParser().print(condition, into: &input)
    return String(input)
}

extension Double {
    /// Prints whole percentages without a trailing `.0` so values round-trip
    /// through the grammar (`50%` rather than `50.0%`).
    var formattedAsConditionPercent: String {
        if self == rounded(), abs(self) < Double(Int.max) {
            return "\(Int(self))"
        }
        return "\(self)"
    }
}

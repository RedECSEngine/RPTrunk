/// Characters that terminate a token: whitespace, chain separators,
/// conjunctions and comparison operators.
private func isTokenTerminator(_ c: Character) -> Bool {
    c.isWhitespace || ".&|,><=!".contains(c)
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
        if body == "target" { return .target }
        if body == "self" { return .oneself }
        if body == "has" { return .has }
        if body == "uses" { return .uses }
        if body == "holds" { return .holds }
        if body == "threat" { return .threat }
        if let value = RPValue(body) {
            return .value(value)
        }
        if body.hasSuffix("%") {
            let stem = String(body.dropLast())
            if let percent = Double(stem) {
                return .percent(percent)
            }
            guard !stem.isEmpty, Double(stem) == nil else {
                throw ConditionSyntaxError.malformedPercentValue(body)
            }
            return .keyword(stem, usePercent: true)
        }
        return .keyword(body, usePercent: false)
    }

    static func text(for token: ConditionToken) -> String {
        switch token {
        case .target:
            return "target"
        case .oneself:
            return "self"
        case .has:
            return "has"
        case .uses:
            return "uses"
        case .holds:
            return "holds"
        case .threat:
            return "threat"
        case let .keyword(name, usePercent):
            return usePercent ? "\(name)%" : name
        case let .value(value):
            return "\(value)"
        case let .percent(value):
            return "\(value.formattedAsConditionPercent)%"
        }
    }
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

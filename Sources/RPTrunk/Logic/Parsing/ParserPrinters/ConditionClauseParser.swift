private func consumeWhitespace(_ input: inout Substring) {
    let spaces = input.prefix(while: \.isWhitespace)
    input.removeFirst(spaces.count)
}

struct ConditionClauseParser: ConditionParserPrinter {
    func parse(_ input: inout Substring) throws -> ConditionClause {
        consumeWhitespace(&input)
        var isNegated = false
        if input.first == "!", input.dropFirst().first != "=" {
            input.removeFirst()
            consumeWhitespace(&input)
            isNegated = true
        }
        let lhs = try ConditionOperandParser().parse(&input)
        consumeWhitespace(&input)

        let checkpoint = input
        if let op = try? ConditionOperatorParser().parse(&input) {
            consumeWhitespace(&input)
            let rhs = try ConditionOperandParser().parse(&input)
            consumeWhitespace(&input)
            return ConditionClause(lhs: lhs, comparison: .init(op: op, rhs: rhs), isNegated: isNegated)
        }
        input = checkpoint
        return ConditionClause(lhs: lhs, comparison: nil, isNegated: isNegated)
    }

    func print(_ output: ConditionClause, into input: inout Substring) throws {
        var text = output.isNegated ? "!" : ""
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

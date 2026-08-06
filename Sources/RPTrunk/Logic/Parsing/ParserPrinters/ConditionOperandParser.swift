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

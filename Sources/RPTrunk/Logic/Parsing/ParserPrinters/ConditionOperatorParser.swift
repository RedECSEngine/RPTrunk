struct ConditionOperatorParser: ConditionParserPrinter {
    func parse(_ input: inout Substring) throws -> RPConditionalOperator {
        let body = input.prefix(while: { "><=!".contains($0) })
        guard let op = RPConditionalOperator(rawValue: String(body)) else {
            throw ConditionSyntaxError.expectedOperator
        }
        input.removeFirst(body.count)
        return op
    }

    func print(_ output: RPConditionalOperator, into input: inout Substring) throws {
        input.insert(contentsOf: output.rawValue, at: input.startIndex)
    }
}

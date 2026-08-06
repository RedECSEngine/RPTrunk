/// Minimal in-house parser-printer contract. The grammar is small,
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

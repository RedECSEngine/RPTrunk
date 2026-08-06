struct ConditionParser: ConditionParserPrinter {
    func parse(_ input: inout Substring) throws -> ParsedCondition {
        var orGroups: [[ConditionClause]] = []
        var group = [try ConditionClauseParser().parse(&input)]
        while true {
            if input.hasPrefix("&&") {
                input.removeFirst(2)
                group.append(try ConditionClauseParser().parse(&input))
            } else if input.hasPrefix("||") {
                input.removeFirst(2)
                orGroups.append(group)
                group = [try ConditionClauseParser().parse(&input)]
            } else {
                break
            }
        }
        orGroups.append(group)
        return ParsedCondition(orGroups: orGroups)
    }

    func print(_ output: ParsedCondition, into input: inout Substring) throws {
        var groupTexts: [String] = []
        for group in output.orGroups {
            var clauseTexts: [String] = []
            for clause in group {
                var clauseInput = Substring()
                try ConditionClauseParser().print(clause, into: &clauseInput)
                clauseTexts.append(String(clauseInput))
            }
            groupTexts.append(clauseTexts.joined(separator: " && "))
        }
        input.insert(contentsOf: groupTexts.joined(separator: " || "), at: input.startIndex)
    }
}

public func parseCondition(_ condition: String) throws -> ParsedCondition {
    try ConditionParser().parse(condition)
}

/// Renders a parsed condition back to its canonical string form.
public func printCondition(_ condition: ParsedCondition) throws -> String {
    var input = Substring()
    try ConditionParser().print(condition, into: &input)
    return String(input)
}

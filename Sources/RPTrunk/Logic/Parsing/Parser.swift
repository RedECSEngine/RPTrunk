
// MARK: - Compilation

// Binds a parsed condition syntax tree to a concrete `RPSpace`, turning
// tokens into the evaluation chain executed against live game state.

func compileOperand<RP: RPSpace>(_ operand: ConditionOperand) throws -> [ParserResultType<RP>] {
    try operand.tokens.map { token -> ParserResultType<RP> in
        switch token {
        case .target:
            return .evaluationFunction(f: getTarget)
        case let .identifier(name, usePercent):
            guard RP.statTypes.contains(name) else {
                throw ConditionalInterpretationError.invalidSyntax(reason: "Unknown stat: \(name)")
            }
            return .evaluationFunction(f: getStat(name, usePercent: usePercent))
        case let .status(name):
            return .evaluationFunction(f: getStatus(name))
        case let .value(value):
            return .valueResult(.rpValue(value))
        case let .percent(value):
            return .valueResult(.percent(value))
        case let .bool(value):
            return .valueResult(.bool(value))
        }
    }
}

func compileClause<RP: RPSpace>(_ clause: ConditionClause) throws -> Conditional<RP>.Predicate {
    let lhs: [ParserResultType<RP>] = try compileOperand(clause.lhs)

    if let comparison = clause.comparison {
        let op = comparison.op
        let rhs: [ParserResultType<RP>] = try compileOperand(comparison.rhs)
        return { entity, rpSpace -> Bool in
            let lhsResult = extractValue(entity, evaluators: lhs, in: rpSpace)
            let rhsResult = extractValue(entity, evaluators: rhs, in: rpSpace)
            guard let l = lhsResult, let r = rhsResult else {
                return false
            }
            guard l.canCompare(to: r) else {
                throw ConditionalInterpretationError.cantCompareValues
            }
            return op.evaluate(l, r)
        }
    }

    // A clause without a comparison must be a bare status query, e.g. "Healing?"
    guard clause.lhs.tokens.count == 1, case .status = clause.lhs.tokens[0] else {
        throw ConditionalInterpretationError.invalidSyntax(
            reason: "A clause without an operator must be a status query"
        )
    }
    return { entity, rpSpace -> Bool in
        extractValue(entity, evaluators: lhs, in: rpSpace) == .bool(true)
    }
}

func compileCondition<RP: RPSpace>(_ condition: ParsedCondition) throws -> Conditional<RP>.Predicate {
    let predicates: [Conditional<RP>.Predicate] = try condition.clauses.map(compileClause)
    if predicates.count == 1 {
        return predicates[0]
    }
    return { entity, rpSpace in
        // all clauses must hold
        try predicates.contains(where: { predicate -> Bool in
            try !predicate(entity, rpSpace)
        }) == false
    }
}

func interpretStringCondition<RP: RPSpace>(_ condition: String) throws -> Conditional<RP>.Predicate {
    let parsed: ParsedCondition
    do {
        parsed = try parseCondition(condition)
    } catch {
        throw ConditionalInterpretationError.invalidSyntax(reason: "Could not parse: \(error)")
    }
    return try compileCondition(parsed)
}

// MARK: - Value extraction

func extractValue<RP: RPSpace>(
    _ entity: RPEntityId,
    evaluators: [ParserResultType<RP>],
    in rpSpace: RP
) -> ParserValueType? {
    let initial = ParserResultType<RP>.entityResult(entity: entity)

    let final = evaluators.reduce(initial, {
        prev, current -> ParserResultType<RP> in

        if case let .evaluationFunction(f) = current {
            return f(prev, rpSpace)
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

public func extractValue<RP: RPSpace>(
    _ entity: RPEntityId,
    evaluate evaluationString: String,
    in rpSpace: RP
) -> ParserValueType? {
    var trimmed = Substring(evaluationString)
    while let first = trimmed.first, first.isWhitespace { trimmed.removeFirst() }
    while let last = trimmed.last, last.isWhitespace { trimmed.removeLast() }
    guard
        let operand = try? ConditionOperandParser().parse(trimmed),
        let evaluators: [ParserResultType<RP>] = try? compileOperand(operand)
    else {
        return nil
    }
    return extractValue(entity, evaluators: evaluators, in: rpSpace)
}

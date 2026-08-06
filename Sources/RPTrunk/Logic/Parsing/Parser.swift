
// MARK: - Compilation

// Binds a parsed condition syntax tree to a concrete `RPSpace`, turning
// tokens into the evaluation chain executed against live game state.

func compileOperand<RP: RPSpace>(_ operand: ConditionOperand) throws -> [ParserResultType<RP>] {
    var evaluators: [ParserResultType<RP>] = []
    var index = 0
    while index < operand.tokens.count {
        switch operand.tokens[index] {
        case .target:
            evaluators.append(.evaluationFunction(f: getTarget))
        case .oneself:
            guard index == 0 else {
                throw ConditionalInterpretationError.invalidSyntax(reason: "`self` can only start a chain")
            }
            evaluators.append(.evaluationFunction(f: getInitiator()))
        case .has:
            guard index + 1 < operand.tokens.count,
                  case let .keyword(name, usePercent: false) = operand.tokens[index + 1]
            else {
                throw ConditionalInterpretationError.invalidSyntax(
                    reason: "`has.` must be followed by a status tag, e.g. `has.bleed`"
                )
            }
            evaluators.append(.evaluationFunction(f: getStatus(name)))
            index += 1
        case .uses:
            guard index + 1 < operand.tokens.count,
                  case let .keyword(name, usePercent: false) = operand.tokens[index + 1]
            else {
                throw ConditionalInterpretationError.invalidSyntax(
                    reason: "`uses.` must be followed by an ability tag, e.g. `uses.magical`"
                )
            }
            evaluators.append(.evaluationFunction(f: getUsesAbilityTag(name)))
            index += 1
        case .threat:
            evaluators.append(.evaluationFunction(f: getThreat()))
        case let .keyword(name, usePercent):
            guard RP.statTypes.contains(name) else {
                throw ConditionalInterpretationError.invalidSyntax(reason: "Unknown stat: \(name)")
            }
            evaluators.append(.evaluationFunction(f: getStat(name, usePercent: usePercent)))
        case let .value(value):
            evaluators.append(.valueResult(.rpValue(value)))
        case let .percent(value):
            evaluators.append(.valueResult(.percent(value)))
        }
        index += 1
    }
    return evaluators
}

func compileClause<RP: RPSpace>(_ clause: ConditionClause) throws -> RPConditional<RP>.Predicate {
    let lhs: [ParserResultType<RP>] = try compileOperand(clause.lhs)

    if let comparison = clause.comparison {
        guard !clause.isNegated else {
            throw ConditionalInterpretationError.invalidSyntax(
                reason: "`!` negates a `has.` or `uses.` tag query, not a comparison"
            )
        }
        let op = comparison.op
        let rhs: [ParserResultType<RP>] = try compileOperand(comparison.rhs)
        return { context, rpSpace -> Bool in
            let lhsResult = extractValue(context, evaluators: lhs, in: rpSpace)
            let rhsResult = extractValue(context, evaluators: rhs, in: rpSpace)
            guard let l = lhsResult, let r = rhsResult else {
                return false
            }
            guard l.canCompare(to: r) else {
                throw ConditionalInterpretationError.cantCompareValues
            }
            return op.evaluate(l, r)
        }
    }

    switch (clause.lhs.tokens.first, clause.lhs.tokens.count) {
    case (.has, 2), (.uses, 2):
        break
    default:
        throw ConditionalInterpretationError.invalidSyntax(
            reason: "A clause without an operator must be a `has.` or `uses.` tag query"
        )
    }
    let isNegated = clause.isNegated
    return { context, rpSpace -> Bool in
        (extractValue(context, evaluators: lhs, in: rpSpace) == .bool(true)) != isNegated
    }
}

func compileCondition<RP: RPSpace>(_ condition: ParsedCondition) throws -> RPConditional<RP>.Predicate {
    let groups: [[RPConditional<RP>.Predicate]] = try condition.orGroups.map { group in
        try group.map(compileClause)
    }
    if groups.count == 1, groups[0].count == 1 {
        return groups[0][0]
    }
    return { context, rpSpace in
        try groups.contains { group in
            try group.allSatisfy { try $0(context, rpSpace) }
        }
    }
}

func interpretStringCondition<RP: RPSpace>(_ condition: String) throws -> RPConditional<RP>.Predicate {
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
    _ context: RPConditionContext,
    evaluators: [ParserResultType<RP>],
    in rpSpace: RP
) -> ParserValueType? {
    let initial = ParserResultType<RP>.bodyResult(body: context.body)

    let final = evaluators.reduce(initial, {
        prev, current -> ParserResultType<RP> in

        if case let .evaluationFunction(f) = current {
            return f(prev, context, rpSpace)
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
    _ context: RPConditionContext,
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
    return extractValue(context, evaluators: evaluators, in: rpSpace)
}

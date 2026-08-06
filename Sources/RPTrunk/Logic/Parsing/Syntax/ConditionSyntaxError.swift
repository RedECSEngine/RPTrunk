enum ConditionSyntaxError: Error, Equatable {
    case expectedToken
    case expectedOperator
    case malformedPercentValue(String)
    case unexpectedTrailingCharacters(String)
}

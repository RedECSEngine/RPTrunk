enum ConditionSyntaxError: Error {
    case expectedToken
    case expectedOperator
    case malformedPercentValue(String)
    case unexpectedTrailingCharacters(String)
}

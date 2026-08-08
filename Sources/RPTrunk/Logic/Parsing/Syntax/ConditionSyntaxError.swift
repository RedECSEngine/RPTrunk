enum ConditionSyntaxError: Error, Equatable {
    case expectedToken
    case expectedOperator
    case malformedPercentValue(String)
    case unexpectedTrailingCharacters(String)
    case expectedTagList(String)
    case unknownTagQueryKeyword(String)
    case unterminatedTagList
    case malformedTag(String)
}

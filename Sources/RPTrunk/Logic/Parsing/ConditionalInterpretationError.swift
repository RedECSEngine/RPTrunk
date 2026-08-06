enum ConditionalInterpretationError: Error {
    case invalidSyntax(reason: String)
    case cantCompareValues
}

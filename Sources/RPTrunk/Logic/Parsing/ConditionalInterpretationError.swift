enum ConditionalInterpretationError: Error, Equatable {
    case invalidSyntax(reason: String)
    case cantCompareValues
}

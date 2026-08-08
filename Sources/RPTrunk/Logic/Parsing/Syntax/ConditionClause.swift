public struct ConditionClause: Equatable {
    public var lhs: ConditionOperand
    public var comparison: ConditionComparison?
    public var isNegated: Bool

    public init(lhs: ConditionOperand, comparison: ConditionComparison? = nil, isNegated: Bool = false) {
        self.lhs = lhs
        self.comparison = comparison
        self.isNegated = isNegated
    }
}

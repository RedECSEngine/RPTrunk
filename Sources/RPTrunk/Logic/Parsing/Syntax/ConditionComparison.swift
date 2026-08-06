public struct ConditionComparison: Equatable {
    public var op: RPConditionalOperator
    public var rhs: ConditionOperand

    public init(op: RPConditionalOperator, rhs: ConditionOperand) {
        self.op = op
        self.rhs = rhs
    }
}

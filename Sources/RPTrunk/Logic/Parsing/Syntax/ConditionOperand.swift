/// A dot-notation chain, e.g. `target.hp%`.
public struct ConditionOperand: Equatable {
    public var tokens: [ConditionToken]

    public init(tokens: [ConditionToken]) {
        self.tokens = tokens
    }
}

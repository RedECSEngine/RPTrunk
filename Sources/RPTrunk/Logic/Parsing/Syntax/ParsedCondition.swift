/// A full condition: `&&`-joined clause groups, themselves joined by `||`,
/// with `&&` binding tighter than `||`.
public struct ParsedCondition: Equatable {
    public var orGroups: [[ConditionClause]]

    public init(orGroups: [[ConditionClause]]) {
        self.orGroups = orGroups
    }
}

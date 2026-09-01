public enum RPConditionalOperator: String, CaseIterable {
    case greaterThan = ">"
    case lessThan = "<"
    case greaterThanOrEqual = ">="
    case lessThanOrEqual = "<="
    case equal = "=="
    case notEqual = "!="

    public func evaluate<U: Comparable>(_ lhs: U, _ rhs: U) -> Bool {
        toFunc()(lhs, rhs)
    }

    public func toFunc<U: Comparable>() -> (U, U) -> Bool {
        switch self {
        case .equal:
            return isEqual
        case .notEqual:
            return isNotEqual
        case .greaterThan:
            return isGreaterThan
        case .lessThan:
            return isLessThan
        case .greaterThanOrEqual:
            return isGreaterThanOrEqual
        case .lessThanOrEqual:
            return isLessThanOrEqual
        }
    }
}

public func isGreaterThan<U: Comparable>(_ lhs: U, _ rhs: U) -> Bool {
    lhs > rhs
}

public func isLessThan<U: Comparable>(_ lhs: U, _ rhs: U) -> Bool {
    lhs < rhs
}

public func isGreaterThanOrEqual<U: Comparable>(_ lhs: U, _ rhs: U) -> Bool {
    lhs >= rhs
}

public func isLessThanOrEqual<U: Comparable>(_ lhs: U, _ rhs: U) -> Bool {
    lhs <= rhs
}

public func isEqual<U: Comparable>(_ lhs: U, rhs: U) -> Bool {
    lhs == rhs
}

public func isNotEqual<U: Comparable>(_ lhs: U, rhs: U) -> Bool {
    lhs != rhs
}

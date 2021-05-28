
public enum ConditionalOperator: String {
    case GreaterThan = ">"
    case LessThan = "<"
    case Equal = "=="
    case NotEqual = "!="

    public func evaluate<U: Comparable>(_ lhs: U, _ rhs: U) -> Bool {
        return toFunc()(lhs, rhs)
    }

    public func toFunc<U: Comparable>() -> (U, U) -> Bool {
        switch self {
        case .Equal:
            return isEqual
        case .NotEqual:
            return isNotEqual
        case .GreaterThan:
            return isGreaterThan
        case .LessThan:
            return isLessThan
        }
    }
}

public func isGreaterThan<U: Comparable>(_ lhs: U, _ rhs: U) -> Bool {
    return lhs > rhs
}

public func isLessThan<U: Comparable>(_ lhs: U, _ rhs: U) -> Bool {
    return lhs < rhs
}

public func isEqual<U: Comparable>(_ lhs: U, rhs: U) -> Bool {
    return lhs == rhs
}

public func isNotEqual<U: Comparable>(_ lhs: U, rhs: U) -> Bool {
    return lhs != rhs
}


public enum ConditionalPredicate: String {
    case GreaterThan = ">"
    case LessThan = "<"
    case Equal = "=="
}

public func getConditionalPredicate<U:Comparable>(op:ConditionalPredicate) -> U -> U -> Bool {
    switch op {
    case .Equal:
        return isEqual |> rightCurry
    case .GreaterThan:
        return isGreaterThan |> rightCurry
    case .LessThan:
        return isLessThan |> rightCurry
    }
}

public func isGreaterThan<U:Comparable>(lhs:U, _ rhs:U) -> Bool {
    return lhs > rhs
}

public func isLessThan<U:Comparable>(lhs:U, _ rhs:U) -> Bool {
    return lhs < rhs;
}

public func isEqual<U:Comparable>(lhs:U, rhs:U) -> Bool {
    return lhs == rhs;
}

public func rightCurry<U,V>(f:(U, U) -> V) -> U -> (U -> V) {
    
    return { b -> U -> V in
        return { a -> V in
            return f(a, b)
        }
    }
}

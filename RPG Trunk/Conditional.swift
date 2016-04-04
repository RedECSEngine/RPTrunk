
import Foundation

public struct Conditional {
    
    let query: (RPEntity) -> Bool
    
    public init(_ condition:String) {
        do {
            query = try interpretStringCondition(condition)
        } catch {
            print("WARNING: Failed to parse conditional (\(condition))", error)
            query = { _ in false }
        }
    }
    
    public init(_ query: RPEntity -> Bool) {
        self.query = query
    }
    
    public func exec(e:RPEntity) -> Bool {
        return query(e)
    }

}

public func && (a: Conditional, b: Conditional) -> Conditional {
    return Conditional { e in
        return a.exec(e) && b.exec(e)
    }
}

public func || (a: Conditional, b: Conditional) -> Conditional {
    return Conditional { e in
        return a.exec(e) || b.exec(e)
    }
}

public func checkConditionals(conditionals:[Conditional], entity: RPEntity) -> Bool {
    let result = conditionals.reduce([]) { (failures, condition) -> [String] in
        if !condition.exec(entity) {
            return failures + ["Condition failed"]
        }
        return failures
    }
    return result.count == 0;
}

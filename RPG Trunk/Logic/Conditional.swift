
public enum Conditional {
    
    public typealias Predicate = (Entity) -> Bool
    
    case Always
    case Never
    case Custom(Predicate)
    
    public init(_ condition:String) {
        do {
            let query = try interpretStringCondition(condition)
            self = .Custom(query)
        } catch {
            print("WARNING: Failed to parse conditional (\(condition))", error)
            self = .Never
        }
    }
    
    public init(_ query: Entity -> Bool) {
        self = .Custom(query)
    }
    
    public func exec(e: Entity) -> Bool {
        switch self {
        case .Always:
            return true
        case .Never:
            return false
        case .Custom(let query):
            return query(e)
        }
    }

}

extension Conditional: StringLiteralConvertible {

    public typealias ExtendedGraphemeClusterLiteralType = StringLiteralType
    public typealias UnicodeScalarLiteralType = Character
    
    public init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self.init("\(value)")
    }
    
    public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        self.init(value)
    }
    
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
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


// MARK: - Internal access types & functions

enum ConditionalQueryType: Int {
    case Comparison = 3
    case Examination = 1
}

enum ConditionalInterpretationError: ErrorType {
    case IncorrectComponentCount(reason:String)
    case InvalidSyntax(reason:String)
}

func interpretStringCondition(condition:String) throws -> Conditional.Predicate {
    
    let components = try breakdownConditionToComponents(condition)
    
    guard let queryType = ConditionalQueryType(rawValue: components.count) else {
        
        throw ConditionalInterpretationError.IncorrectComponentCount(reason: "Invalid number of components in query")
    }
    
    let lhs:ArraySlice<String> = breakdownComponentDotNotation(components[0])
    let rhs:ArraySlice<String>
    let condOperator:ConditionalOperator
    
    switch queryType {
    case .Examination:
       condOperator = .Equal
       rhs = ["true"]
    case .Comparison:
        rhs = breakdownComponentDotNotation(components[2])
        
        guard let op = ConditionalOperator(rawValue: components[1]) else {
            throw ConditionalInterpretationError.InvalidSyntax(reason: "Operator `\(components[1])` is not recognized")
        }
        
        condOperator = op
    }
    
    let lhsEvaluators = parse(lhs)
    let rhsEvaluators = parse(rhs)
    
    return { (entity) -> Bool in
        
        let lhsResult = extractResult(entity, evaluators: lhsEvaluators)
        let rhsResult = extractResult(entity, evaluators: rhsEvaluators)
        
        guard let l = lhsResult, r = rhsResult else {
            return false
        }
        
        return condOperator.evaluate(l, r)
    }
}

func breakdownConditionToComponents(condition:String) throws -> [String] {
    let components = condition.componentsSeparatedByString(" ")
    return components
}

func breakdownComponentDotNotation(termString:String) -> ArraySlice<String> {
    let components = termString.componentsSeparatedByString(".")
    return ArraySlice(components)
}
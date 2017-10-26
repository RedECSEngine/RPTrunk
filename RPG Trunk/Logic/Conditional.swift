
public enum Conditional {
    
    public typealias Predicate = (Entity) -> Bool
    
    case always
    case never
    case custom(String, Predicate)
    
    public init(_ condition:String) {
        
        guard condition != "always" else {
            self = .always
            return
        }
        
        do {
            let predicate = try interpretStringCondition(condition)
            self = .custom(condition, predicate)
        } catch {
            print("WARNING: Failed to parse conditional (\(condition)). Will NEVER fire", error)
            self = .never
        }
    }
    
    public init(_ condition:String, _ predicate: @escaping (Entity) -> Bool) {
        self = .custom(condition, predicate)
    }
    
    public func exec(_ e: Entity) -> Bool {
        switch self {
        case .always:
            return true
        case .never:
            return false
        case .custom(_ ,let query):
            return query(e)
        }
    }
}

extension Conditional: CustomStringConvertible {
    public var description:String {
        switch self {
        case .always:
            return "Always"
        case .never:
            return "Never"
        case .custom(let condition, _):
            return condition
        }
    }
}

extension Conditional: Equatable { }

public func ==(lhs:Conditional, rhs:Conditional) -> Bool {
    return lhs.description == rhs.description
}

extension Conditional: ExpressibleByStringLiteral {

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
    let condition = a.description + " && " + b.description
    return Conditional(condition) { e in
        return a.exec(e) && b.exec(e)
    }
}

public func || (a: Conditional, b: Conditional) -> Conditional {
    let condition = a.description + " || " + b.description
    return Conditional(condition) { e in
        return a.exec(e) || b.exec(e)
    }
}


// MARK: - Internal access types & functions

enum ConditionalQueryType: Int {
    case comparison = 3
    case examination = 1
}

enum ConditionalInterpretationError: Error {
    case incorrectComponentCount(reason:String)
    case invalidSyntax(reason:String)
}

func interpretStringCondition(_ condition:String) throws -> Conditional.Predicate {
    
    let components = try breakdownConditionToComponents(condition)
    
    guard let queryType = ConditionalQueryType(rawValue: components.count) else {
        
        throw ConditionalInterpretationError.incorrectComponentCount(reason: "Invalid number of components in query")
    }
    
    let lhs:ArraySlice<String> = breakdownComponentDotNotation(components[0])
    let rhs:ArraySlice<String>
    let condOperator:ConditionalOperator
    
    switch queryType {
    case .examination:
       condOperator = .Equal
       rhs = ["true"]
    case .comparison:
        rhs = breakdownComponentDotNotation(components[2])
        
        guard let op = ConditionalOperator(rawValue: components[1]) else {
            throw ConditionalInterpretationError.invalidSyntax(reason: "Operator `\(components[1])` is not recognized")
        }
        
        condOperator = op
    }
    
    let lhsEvaluators = parse(lhs)
    let rhsEvaluators = parse(rhs)
    
    return { (entity) -> Bool in
        
        let lhsResult = extractResult(entity, evaluators: lhsEvaluators)
        let rhsResult = extractResult(entity, evaluators: rhsEvaluators)
        
        guard let l = lhsResult, let r = rhsResult else {
            return false
        }
        
        return condOperator.evaluate(l, r)
    }
}

func breakdownConditionToComponents(_ condition:String) throws -> [String] {
    let components = condition.components(separatedBy: " ")
    return components
}

func breakdownComponentDotNotation(_ termString:String) -> ArraySlice<String> {
    let components = termString.components(separatedBy: ".")
    return ArraySlice(components)
}

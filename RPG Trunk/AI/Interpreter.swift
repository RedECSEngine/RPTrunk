
public enum ConditionalInterpretationError: ErrorType {
    case IncorrectComponentCount(reason:String)
    case InvalidSyntax(reason:String)
}

public func interpretStringCondition(condition:String) throws -> (RPEntity) -> Bool {
    let components = try breakdownConditionToComponents(condition)
    let lhs = components[0] |> breakdownComponentDotNotation
    let rhs = components[2] |> breakdownComponentDotNotation
    
    guard let predicateId = ConditionalPredicate(rawValue: components[1]) else {
        throw ConditionalInterpretationError.InvalidSyntax(reason: "Predicate Operator `\(components[1])` is not recognized")
    }
    
    return { (entity) -> Bool in
        guard let lhsResult = parse(entity.parser, lhs), rhsResult = parse(entity.parser, rhs) else {
            return false
        }
        let preparedOperation = rhsResult |> getConditionalPredicate(predicateId)
        return lhsResult |> preparedOperation
    }
}

// MARK: - Internal access functions

func breakdownConditionToComponents(condition:String) throws -> [String] {
    let components = condition.componentsSeparatedByString(" ")
    guard components.count == 3 else {
        throw ConditionalInterpretationError.IncorrectComponentCount(reason: "Should be 3 components (left, op, right) separated by spaces")
    }
    return components
}

func breakdownComponentDotNotation(termString:String) -> ArraySlice<String> {
    let components = termString.componentsSeparatedByString(".")
    return ArraySlice(components)
}


//MARK: Parser
public func parse(parser:Parser<String, PropertyResultType>, _ input:ArraySlice<String>) -> RPValue? {
    
    for (res, rem) in parser.p(input) {
        switch res {
        case .Entity(let e):
            return parse(e.parser, rem)
        case .Value(let v):
            return v
        default:
            return nil
        }
    }
    return nil
}

func valueParser() -> Parser<String, PropertyResultType> {
    return Parser { x in
        guard let (head, tail) = x.decompose, value = RPValue(head) else {
            return none()
        }
        return one( (.Value(value: value), tail) )
    }
}

func entityTargetParser(entity:RPEntity) -> Parser<String, PropertyResultType> {
    return Parser { x in
        guard let (head, tail) = x.decompose where head == "target" else {
            return none()
        }
        
        if let tar = entity.target {
            return one( (.Entity(entity: tar), tail) )
        } else {
            return none()
        }
    }
}

func entityStatParser(entity:RPEntity) -> Parser<String, PropertyResultType> {
    return Parser { x in
        guard let (head, tail) = x.decompose else {
            return none()
        }
        
        var type = head
        var usePercent = false
        
        if head.characters.last == "%" {
            type.removeAtIndex(type.endIndex.predecessor())
            usePercent = true
        }
        
        guard RPGameEnvironment.statTypes.contains(type) else {
            return none()
        }
        
        var currentValue = entity[type]
        
        if usePercent {
            let percent:Double = floor(Double(currentValue) / Double(entity.stats[type]) * 100)
            currentValue = RPValue(percent)
        }
        
        return one( (.Value(value: currentValue), tail) )
    }
}

import Foundation

public enum ParserResultType {
    
    case EvaluationFunction(f:ParserResultType -> ParserResultType)
    case EntityResult(entity:Entity)
    case StatsResult(stats:Stats)
    case ValueResult(value:RPValue)
    case BoolResult(value:Bool)
    case Nothing
    
    public static var stringParser:Parser<String, ParserResultType> =
        boolParser()
            <|> valueParser()
            <|> statParser()
            <|> targetParser()
}


public func parse(input:ArraySlice<String>) -> [ParserResultType] {
    
    return ParserResultType.stringParser.p(input).map { $0.0 }
    
}

func targetParser() -> Parser<String, ParserResultType> {
    return Parser { x in
        guard let (head, tail) = x.decompose where head == "target" else {
            return none()
        }
        return one( (.EvaluationFunction(f:getTarget), tail) )
    }
}

func getTarget(input:ParserResultType) -> ParserResultType {
    if case let .EntityResult(e) = input where e.target != nil {
        return .EntityResult(entity: e.target!)
    }
    return .Nothing
}

func statParser() -> Parser<String, ParserResultType> {
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
        
        let function = getStat(type, usePercent: usePercent)
        
        return one( (.EvaluationFunction(f: function), tail) )
    }
}

func getStat(type:String, usePercent:Bool) -> ParserResultType -> ParserResultType {
    
    return {
        input in
        
        if case let .EntityResult(e) = input {
            
            var currentValue = e[type]
            
            if usePercent {
                
                let percent:Double = floor(Double(currentValue) / Double(e.stats[type]) * 100)
                currentValue = RPValue(percent)
            }
            
            return .ValueResult(value: currentValue)
        }
        
        return .Nothing
    }
}

func valueParser() -> Parser<String, ParserResultType> {
    return Parser { x in
        guard let (head, tail) = x.decompose, value = RPValue(head) else {
            return none()
        }
        return one( (.ValueResult(value: value), tail) )
    }
}

func boolParser() -> Parser<String, ParserResultType> {
    return Parser { x in
        guard let (head, tail) = x.decompose else {
            return none()
        }
        
        if head == "true" {
            return one( (.BoolResult(value: true), tail) )
        } else if head == "false" {
            return one( (.BoolResult(value: false), tail) )
        }
        
        return none()
    }
}
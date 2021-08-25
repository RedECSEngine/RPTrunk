import Foundation
import Parsing

func buildEvaluatableParser<RP: RPSpace>() -> AnyParser<Substring, ParserResultType<RP>> {
    let boolParser = Bool.parser().map { ParserResultType<RP>.valueResult(.bool($0)) }
    
    let valueParser = Skip(Prefix(while: { $0 == " " }))
        .take(Prefix(while: { $0 != " " }))
        .flatMap({ result -> AnyParser<Substring, ParserResultType<RP>> in
            var value = result
            var usePercent = false
            
            if result.last == "%" {
                value.removeLast()
                usePercent = true
            }
            
            if usePercent {
                guard let value = Double(String(value)) else {
                    return Fail().eraseToAnyParser()
                }
                return Always(.valueResult(.percent(value))).eraseToAnyParser()
            }
            
            guard let value = RPValue(String(value)) else {
                return Fail().eraseToAnyParser()
            }
            
            return Always(.valueResult(.rpValue(value))).eraseToAnyParser()
        })
    
    let statParser = Parsing.AnyParser<Substring, ParserResultType<RP>> { input in
        var type = input
        var usePercent = false
        
        if input.last == "%" {
            type.removeLast()
            usePercent = true
        }
        
        guard RP.statTypes.contains(String(type)) else {
            return nil
        }
        
        return ParserResultType.evaluationFunction(f: getStat(String(type), usePercent: usePercent))
    }
    
    let targetParser = Parsing
        .StartsWith<Substring>("target")
        .map { _ in
            ParserResultType<RP>.evaluationFunction(f: getTarget)
        }
    
    let evaluatableParser = Parsing.OneOfMany([
        targetParser.eraseToAnyParser(),
        statParser,
        buildStatusParser(),
        valueParser.eraseToAnyParser(),
        boolParser.eraseToAnyParser()
    ])
    return evaluatableParser.eraseToAnyParser()
}

func buildDotNotationParser<RP: RPSpace>() -> AnyParser<Substring, [ParserResultType<RP>]> {
    let evaluatableParser: AnyParser<Substring, ParserResultType<RP>> = buildEvaluatableParser()
    let dotNotationParser =
    Skip(Prefix(while: { $0 == " " }))
        .take(Prefix(while: { $0 != " " }))
        .flatMap({ result -> AnyParser<Substring, [ParserResultType<RP>]> in
            if let parseResult = Parsing
                .Many(evaluatableParser, separator: StartsWith("."))
                .parse(result).output {
                return Always(parseResult).eraseToAnyParser()
            }
            return Fail().eraseToAnyParser()
        })
    return dotNotationParser.eraseToAnyParser()
}

func buildStatusParser<RP: RPSpace>() -> AnyParser<Substring, ParserResultType<RP>> {
    let statusParser =
        Skip(Prefix(while: { $0 == " " }))
        .take(Prefix(while: { $0 != " " }))
        .flatMap({ result -> AnyParser<Substring, ParserResultType<RP>> in
            guard result.last == "?" else {
                return Fail().eraseToAnyParser()
            }
            
            let status = String(result.dropLast())
            return Always(.evaluationFunction(f: getStatus(status))).eraseToAnyParser()
        })
    
    return statusParser.eraseToAnyParser()
}

func buildLogicalOperatorParser() -> AnyParser<Substring, ConditionalOperator> {
    let logicalOperatorParser =
    Skip(Prefix(while: { $0 == " " }))
        .take(Prefix(while: { $0 != " " }))
        .flatMap({ result -> AnyParser<Substring, ConditionalOperator> in
            if let enumResult = ConditionalOperator(rawValue: String(result)) {
                return Parsing.Always(enumResult).eraseToAnyParser()
            }
            return Fail().eraseToAnyParser()
        })
    return logicalOperatorParser.eraseToAnyParser()
}

func buildParser
<RP: RPSpace>
    () -> AnyParser<Substring, ([ParserResultType<RP>], ConditionalOperator, [ParserResultType<RP>])> {
    
    let dotNotationParser: AnyParser<Substring, [ParserResultType<RP>]>  = buildDotNotationParser()
    let logicalComparisonParser =
    dotNotationParser
        .take(buildLogicalOperatorParser())
        .take(dotNotationParser)
    
    return logicalComparisonParser.eraseToAnyParser()
}


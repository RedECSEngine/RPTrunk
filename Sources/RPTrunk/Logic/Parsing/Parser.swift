import Foundation
import Parsing
    
let boolParser = Bool.parser().map { ParserResultType.valueResult(.bool($0)) }

let valueParser =
    Skip(Prefix(while: { $0 == " " }))
    .take(Prefix(while: { $0 != " " }))
    .flatMap({ result -> AnyParser<Substring, ParserResultType> in
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
    
//AnyParser<Substring, ParserResultType> { input in
//    guard let value = RPValue(String(input)) else {
//        return nil
//    }
//    return .valueResult(.rpValue(value))
//}

let evaluatableParser = Parsing.OneOfMany([
    targetParser.eraseToAnyParser(),
    statParser,
    statusParser.eraseToAnyParser(),
    valueParser.eraseToAnyParser(),
    boolParser.eraseToAnyParser()
])

let dotNotationParser =
    Skip(Prefix(while: { $0 == " " }))
    .take(Prefix(while: { $0 != " " }))
    .flatMap({ result -> AnyParser<Substring, [ParserResultType]> in
        if let parseResult = Parsing
            .Many(evaluatableParser, separator: StartsWith("."))
            .parse(result).output {
            return Always(parseResult).eraseToAnyParser()
        }
        return Fail().eraseToAnyParser()
    })

let logicalOperatorParser =
    Skip(Prefix(while: { $0 == " " }))
    .take(Prefix(while: { $0 != " " }))
    .flatMap({ result -> AnyParser<Substring, ConditionalOperator> in
        if let enumResult = ConditionalOperator(rawValue: String(result)) {
            return Parsing.Always(enumResult).eraseToAnyParser()
        }
        return Fail().eraseToAnyParser()
    })

let logicalComparisonParser =
    dotNotationParser
    .take(logicalOperatorParser)
    .take(dotNotationParser)

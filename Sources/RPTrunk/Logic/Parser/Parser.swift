import Foundation

extension ArraySlice {
    var decompose: (Element, ArraySlice<Element>)? {
        return isEmpty ? nil : (self[startIndex], ArraySlice(dropFirst()))
    }
}

public struct Parser<Token, Result> {
    public let p: (ArraySlice<Token>) -> AnySequence<(Result, ArraySlice<Token>)>
    public init(_ p: @escaping (ArraySlice<Token>) -> AnySequence<(Result, ArraySlice<Token>)>) {
        self.p = p
    }
}

public func + <G: IteratorProtocol, H: IteratorProtocol>(first: G, second: H) -> AnyIterator<G.Element> where G.Element == H.Element {
    var one = first, two = second
    return AnyIterator { one.next() ?? two.next() }
}

public func + <A>(l: AnySequence<A>, r: AnySequence<A>) -> AnySequence<A> {
    return AnySequence { l.makeIterator() + r.makeIterator() }
}

public func one<A>(_ x: A) -> AnySequence<A> {
    return AnySequence(CollectionOfOne(x))
}

public func none<A>() -> AnySequence<A> {
    return AnySequence(AnyIterator { nil })
}

precedencegroup OrPipe {
    associativity: right
}

infix operator <|>: OrPipe
public func <|> <Token, A>(l: Parser<Token, A>, r: Parser<Token, A>) -> Parser<Token, A> {
    return Parser { l.p($0) + r.p($0) }
}

public enum ParserResultType {
    case evaluationFunction(f: (ParserResultType) -> ParserResultType)
    case entityResult(entity: Entity)
    case statsResult(stats: Stats)
    case valueResult(value: RPValue)
    case boolResult(value: Bool)
    case nothing

    public static var stringParser: Parser<String, ParserResultType> =
        boolParser()
            <|> valueParser()
            <|> targetParser()
            <|> statParser()
            <|> statusParser()
}

public func parse(_ input: ArraySlice<String>) -> [ParserResultType] {
    for (res, rem) in ParserResultType.stringParser.p(input) {
        return [res] + parse(rem)
    }

    return []
}

public func extractResult(_ entity: Entity, evaluators: [ParserResultType]) -> RPValue? {
    let initial = ParserResultType.entityResult(entity: entity)

    let final = evaluators.reduce(initial) {
        prev, current -> ParserResultType in

        if case let .evaluationFunction(f) = current {
            return f(prev)
        }

        return current
    }

    switch final {
    case let .valueResult(v):
        return v
    case let .boolResult(v):
        return RPValue(v ? 1 : 0)
    default:
        return nil
    }
}

func targetParser() -> Parser<String, ParserResultType> {
    return Parser { x in
        guard let (head, tail) = x.decompose, head == "target" else {
            return none()
        }
        return one((.evaluationFunction(f: getTarget), tail))
    }
}

func getTarget(_ input: ParserResultType) -> ParserResultType {
    if case let .entityResult(e) = input, let target = e.getTarget() {
        return .entityResult(entity: target)
    }
    return .nothing
}

func statParser() -> Parser<String, ParserResultType> {
    return Parser { x in
        guard let (head, tail) = x.decompose else {
            return none()
        }

        var type = head
        var usePercent = false

        if head.last == "%" {
            type.remove(at: type.index(before: type.endIndex))
            usePercent = true
        }

        guard RPGameEnvironment.statTypes.contains(type) else {
            return none()
        }

        let function = getStat(type, usePercent: usePercent)

        return one((.evaluationFunction(f: function), tail))
    }
}

func getStat(_ type: String, usePercent: Bool) -> (ParserResultType) -> ParserResultType {
    return {
        input in

        if case let .entityResult(e) = input {
            var currentValue = e[type]

            if usePercent {
                let percent: Double = floor(Double(currentValue) / Double(e.stats[type]) * 100)
                currentValue = RPValue(percent)
            }

            return .valueResult(value: currentValue)
        }

        return .nothing
    }
}

func statusParser() -> Parser<String, ParserResultType> {
    return Parser { x in
        guard let (head, tail) = x.decompose else {
            return none()
        }

        guard head.last == "?" else {
            return none()
        }

        let status = String(head.dropLast())
        let function = getStatus(status)

        return one((.evaluationFunction(f: function), tail))
    }
}

func getStatus(_ status: String) -> (ParserResultType) -> ParserResultType {
    return {
        input in
        if case let .entityResult(e) = input {
            let found = e.hasStatus(status)
            return .boolResult(value: found)
        }
        return .nothing
    }
}

func valueParser() -> Parser<String, ParserResultType> {
    return Parser { x in
        guard let (head, tail) = x.decompose, let value = RPValue(head) else {
            return none()
        }
        return one((.valueResult(value: value), tail))
    }
}

func boolParser() -> Parser<String, ParserResultType> {
    return Parser { x in
        guard let (head, tail) = x.decompose else {
            return none()
        }

        if head == "true" {
            return one((.boolResult(value: true), tail))
        } else if head == "false" {
            return one((.boolResult(value: false), tail))
        }

        return none()
    }
}

/*
 infix operator </> { precedence 170 }
 public func </> <Token, A, B>(l:A -> B, r:Parser<Token,A>) -> Parser<Token, B> {
 return pure(l) <*> r
 }

 infix operator <* { associativity left precedence 150 }
 public func <* <Token, A, B>(p: Parser<Token, A>, q: Parser<Token, B>) -> Parser<Token, A> {
 return { x in { _ in x } } </> p <*> q
 }

 infix operator *> { associativity left precedence 150 }
 public func *> <Token, A, B>(p: Parser<Token, A>, q: Parser<Token, B>) -> Parser<Token, B> {
 return { _ in { y in y } } </> p <*> q
 }

 infix operator <*> { associativity left precedence 150 }
 public func <*><Token, A, B>(l:Parser<Token, A -> B>,  r: Parser<Token, A>) -> Parser<Token, B>{
 return combinator(l, r)
 }

 public func pure<Token, A>(value: A) -> Parser<Token, A> {
 return Parser { one((value, $0)) }
 }

 public func combinator<Token, A, B>(l:Parser<Token, A -> B>, _ r: Parser<Token, A>) -> Parser<Token, B> {
 typealias Result = (B, ArraySlice<Token>)
 typealias Results = [Result]
 return Parser { input in
 let leftResults = l.p(input)
 let result = leftResults.flatMap {
 f, leftRemainder -> Results in
 let rightResults = r.p(leftRemainder)
 return rightResults.map {
 x, rightRemainder -> Result in
 (f(x), rightRemainder)
 }
 }
 return AnySequence(result)
 }
 }

 /////////

 public func satisfy<Token>(predicate: Token -> Bool) -> Parser<Token, Token> {
 return Parser { x in
 guard let (head, tail) = x.decompose where predicate(head) else {
 return none()
 }
 return one((head, tail))
 }
 }

 public func token<Token: Equatable>(t:Token) -> Parser<Token, Token> {
 return satisfy { $0 == t }
 }

 public func testParser<A>(parser: Parser<Character, A>, _ input: String) -> String {
 var result: [String] = []
 for (x, s) in parser.p(ArraySlice(input.characters)) {
 result += ["Success, found \(x), remainder: \(Array(s))"]
 }
 return result.isEmpty ? "Parsing failed." : result.joinWithSeparator("\n")
 }

 public func sequence<Token, A, B>(l: Parser<Token, A>, _ r: Parser<Token, B>) -> Parser<Token, (A, B)> {
 return Parser { input in
 let leftResults = l.p(input)
 let result = leftResults.flatMap {
 (a, leftRest) -> [((A, B), ArraySlice<Token>)] in
 let rightResults = r.p(leftRest)
 return rightResults.map {
 b, rightRest in
 return ((a, b), rightRest)
 }
 }
 return AnySequence(result)
 }
 }

 public func prepend<A>(l: A) -> [A] -> [A] {
 return { r -> [A] in [l] + r }
 }

 public func lazy<Token, A>(f: () -> Parser<Token, A>) -> Parser<Token, A> {
 return Parser { f().p($0) }
 }

 public func zeroOrMore<Token, A>(p: Parser<Token, A>) -> Parser<Token, [A]> {
 return pure(prepend) <*> p <*> lazy { zeroOrMore(p) } <|> pure([])
 }

 public func oneOrMore<Token, A>(p: Parser<Token, A>) -> Parser<Token, [A]> {
 return pure(prepend) <*> p <*> zeroOrMore(p)
 }

 let testSeq = sequence(token("3"), token("4"))
 var res:[String] = []
 for (x, s) in testSeq.p(ArraySlice(["3", "4"])) {
 res += ["Success, found \(x), remainder: \(Array(s))"]
 }
 res

 func toInt(c:Character) -> Int {
 return Int(String(c))!
 }

 func toInt2(c1:Character) -> Character -> Int {

 return { c2 -> Int in
 let combined = String(c1) + String(c2)
 return Int(combined)!
 }
 }

 testParser(pure(toInt2) <*> token("3") <*> token("3"), "33")

 extension NSCharacterSet {
 func member(c:Character) -> Bool {
 let s = String(c)
 var codeUnits = [unichar]()
 for codeUnit in s.utf16 {
 codeUnits.append(codeUnit)
 }
 return self.characterIsMember(codeUnits[0])
 }
 }

 func characterFromSet(set:NSCharacterSet) -> Parser<Character, Character> {
 return satisfy(set.member)
 }

 let decimals = NSCharacterSet.decimalDigitCharacterSet()
 let decimalDigit = characterFromSet(decimals)

 testParser(zeroOrMore(decimalDigit), "123")

 testParser(decimalDigit, "012")

 testParser(oneOrMore(decimalDigit), "12")

 let number = pure { Int(String($0))! } <*> oneOrMore(decimalDigit)
 testParser(number, "12345")

 func multiply(a:Int) -> Int -> Int {
 return { b -> Int in
 return a * b
 }
 }

 let parseMultiply = multiply </> number <* token("*") <*> number
 testParser(parseMultiply, "8*8")

 func prependToken<Token>(item: Token) -> Parser<Token, Token> {
 return Parser({ x in
 let appended = ArraySlice([item]) + x
 return one((item, appended))
 })
 }

 let entitySeq = sequence(token(1), token("self"))

 let parseTarget = token("self") <|> token("selfie") <|> pure("hi mom")
 //let parseTarget = prependToken(2) <|> prependToken(1) <|> token("self")
 //testParser(parseTarget, "hi")

 var result: [String] = []
 var parsedSeq = parseTarget.p(ArraySlice(["selfo", "selfie"]))
 var parsedGen = parsedSeq.generate()
 parsedGen.next()
 parsedGen.next()
 parsedGen.next()

 for (x, s) in parsedSeq {
 result += ["Success, found \(x), remainder: \(Array(s))"]
 }
 result

 */

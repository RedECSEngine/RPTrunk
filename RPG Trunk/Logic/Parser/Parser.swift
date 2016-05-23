import Foundation

extension ArraySlice {
    var decompose: (Element, ArraySlice<Element>)? {
        return isEmpty ? nil : (self[startIndex], ArraySlice(self.dropFirst()))
    }
}

public struct Parser<Token, Result> {
    public let p: ArraySlice<Token> -> AnySequence<(Result, ArraySlice<Token>)>
    public init(_ p:ArraySlice<Token> -> AnySequence<(Result, ArraySlice<Token>)>) {
        self.p = p
    }
}

public func +<G:GeneratorType, H:GeneratorType where G.Element == H.Element>(first: G, second:H) -> AnyGenerator<G.Element> {
    var one = first, two = second
    return AnyGenerator { one.next() ?? two.next() }
}

public func +<A>(l: AnySequence<A>, r: AnySequence<A>) -> AnySequence<A> {
    return AnySequence { l.generate() + r.generate() }
}

public func one<A>(x: A) -> AnySequence<A> {
    return AnySequence(GeneratorOfOne(x))
}

public func none<A>() -> AnySequence<A> {
    return AnySequence(AnyGenerator { return nil })
}

infix operator <|> { associativity right precedence 130 }
public func <|> <Token, A>(l: Parser<Token, A>, r: Parser<Token,A>) -> Parser<Token, A> {
    return Parser { l.p($0) + r.p($0) }
}

public func parse(parser:Parser<String, PropertyResultType>, _ input:ArraySlice<String>) -> RPValue? {
    
    for (res, rem) in parser.p(input) {
        switch res {
        case .EntityResult(let e):
            return parse(e.parser, rem)
        case .ValueResult(let v):
            return v
        case .BoolResult(let v):
            return RPValue(v)
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
        return one( (.ValueResult(value: value), tail) )
    }
}

func boolParser() -> Parser<String, PropertyResultType> {
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

func entityTargetParser(entity: Entity) -> Parser<String, PropertyResultType> {
    return Parser { x in
        guard let (head, tail) = x.decompose where head == "target" else {
            return none()
        }
        
        if let tar = entity.target {
            return one( (.EntityResult(entity: tar), tail) )
        } else {
            return none()
        }
    }
}

func entityStatParser(entity: Entity) -> Parser<String, PropertyResultType> {
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
        
        return one( (.ValueResult(value: currentValue), tail) )
    }
}

func entityStatusParser(entity: Entity) -> Parser<String, PropertyResultType> {
    return Parser { x in
        guard let (head, tail) = x.decompose else {
            return none()
        }
        
        guard head.characters.last == "?" else {
           return none()
        }
        
        let status:String = String(head.characters.dropLast())
        let found = entity.hasStatus(status)
        return one( (.BoolResult(value: found), tail) )
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
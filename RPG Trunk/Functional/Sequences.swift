
public func +<A>(l: AnySequence<A>, r: AnySequence<A>) -> AnySequence<A> {
    return AnySequence { l.generate() + r.generate() }
}

public func one<A>(x: A) -> AnySequence<A> {
    return AnySequence(GeneratorOfOne(x))
}

public func none<A>() -> AnySequence<A> {
    return AnySequence(AnyGenerator { return nil })
}
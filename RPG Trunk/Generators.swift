
public func +<G:GeneratorType, H:GeneratorType where G.Element == H.Element>(first: G, second:H) -> AnyGenerator<G.Element> {
    var one = first, two = second
    return AnyGenerator { one.next() ?? two.next() }
}
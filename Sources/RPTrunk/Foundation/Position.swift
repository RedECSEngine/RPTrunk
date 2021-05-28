import Foundation

typealias Distance = Double
typealias Region = (Position) -> Bool

struct Position {
    var x: Double
    var y: Double
}

func circle(_ radius: Distance) -> Region {
    { point in point.length <= radius }
}

func shift(_ region: @escaping Region, offset: Position) -> Region {
    { point in region(point.minus(offset)) }
}

func invert(_ region: @escaping Region) -> Region {
    { point in !region(point) }
}

func intersection(_ region1: @escaping Region, _ region2: @escaping Region) -> Region {
    { point in region1(point) && region2(point) }
}

func union(_ region1: @escaping Region, _ region2: @escaping Region) -> Region {
    { point in region1(point) || region2(point) }
}

func difference(_ region: @escaping Region, minus: @escaping Region) -> Region {
    intersection(region, invert(minus))
}

extension Position {
    func inRange(_ range: Distance) -> Bool {
        sqrt(x * x + y * y) <= range
    }

    func minus(_ p: Position) -> Position {
        Position(x: x - p.x, y: y - p.y)
    }

    var length: Double {
        sqrt(x * x + y * y)
    }
}

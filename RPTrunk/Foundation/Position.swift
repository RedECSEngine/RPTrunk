import Foundation

typealias Distance = Double
typealias Region = (Position) -> Bool

struct Position {
    var x: Double
    var y: Double
}

func circle(_ radius: Distance) -> Region {
    return { point in point.length <= radius }
}

func shift(_ region: @escaping Region, offset: Position) -> Region {
    return { point in region(point.minus(offset)) }
}

func invert(_ region:@escaping Region) -> Region {
    return { point in !region(point) }
}

func intersection(_ region1: @escaping Region, _ region2: @escaping Region) -> Region {
    return { point in region1(point) && region2(point) }
}

func union(_ region1: @escaping Region, _ region2: @escaping Region) -> Region {
    return { point in region1(point) || region2(point)}
}

func difference(_ region: @escaping Region, minus: @escaping Region) -> Region {
    return intersection(region, invert(minus))
}

extension Position {
    func inRange(_ range: Distance) -> Bool {
        return sqrt(x * x + y * y) <= range
    }
    
    func minus(_ p: Position) -> Position {
        return Position(x: x - p.x, y: y - p.y)
    }
    
    var length: Double {
        return sqrt(x * x + y * y)
    }
}

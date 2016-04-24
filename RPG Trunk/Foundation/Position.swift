
typealias Distance = Double
typealias Region = Position -> Bool

struct Position {
    var x: Double
    var y: Double
}

func circle(radius: Distance) -> Region {
    return { point in point.length <= radius }
}

func shift(region: Region, offset: Position) -> Region {
    return { point in region(point.minus(offset)) }
}

func invert(region:Region) -> Region {
    return { point in !region(point) }
}

func intersection(region1: Region, _ region2: Region) -> Region {
    return { point in region1(point) && region2(point) }
}

func union(region1: Region, _ region2: Region) -> Region {
    return { point in region1(point) || region2(point)}
}

func difference(region: Region, minus: Region) -> Region {
    return intersection(region, invert(minus))
}

extension Position {
    func inRange(range: Distance) -> Bool {
        return sqrt(x * x + y * y) <= range
    }
    
    func minus(p: Position) -> Position {
        return Position(x: x - p.x, y: y - p.y)
    }
    
    var length: Double {
        return sqrt(x * x + y * y)
    }
}


public protocol RPGameDelegate {

    // instance managers
    var statTypes:[String] { get }
    
    func resolveConflict (target: RPStats, b: RPStats) -> RPStats
}

public class RPGameEnvironment {
    
    // static vars
    static public private(set) var current:RPGameEnvironment! = RPGameEnvironment(delegate: DefaultGame())
    static private var environments:[RPGameEnvironment] = []
    
    static public var statTypes:[String] {
       return RPGameEnvironment.current.delegate.statTypes
    }
    
    public var delegate:RPGameDelegate
    
    // static methods
    static public func pushEnvironment(env:RPGameEnvironment) {
        RPGameEnvironment.environments.append(env)
        RPGameEnvironment.current = env
    }
    
    static public func popEnvironment() {
        RPGameEnvironment.environments.removeLast()
        RPGameEnvironment.current = RPGameEnvironment.environments.last
    }
    
    // instance methods
    public init(delegate:RPGameDelegate) {
        self.delegate = delegate
    }
    
}

public typealias RPValue = Int


public protocol StatsContainer {
    
    var stats:RPStats {get}
}

public enum EventTargetType:Int {
    case Oneself = 1
    case All
    case Random
    case AllFriendly
    case AllEnemy
    case GroupFriendly
    case GroupEnemy
    case SingleFriendly
    case SingleEnemy
    case RandomFriendly
    case RandomEnemy
}

infix operator |> { precedence 50 associativity left }
// Pipe forward: transform "x |> f" to "f(x)" and "x |> f |> g |> h" to "h(g(f(x)))"
public func |> <T,U>(lhs: T, rhs: T -> U) -> U {
    return rhs(lhs)
}

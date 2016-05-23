
import Foundation

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

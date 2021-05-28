
import Foundation

open class RPGameEnvironment {
    
    // static vars
    static public fileprivate(set) var current:RPGameEnvironment! = RPGameEnvironment(delegate: DefaultGame())
    static fileprivate var environments:[RPGameEnvironment] = []
    
    static public var statTypes:[String] {
       return RPGameEnvironment.current.delegate.statTypes
    }
    
    open var delegate:RPGameDelegate
    
    // static methods
    static public func pushEnvironment(_ env:RPGameEnvironment) {
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

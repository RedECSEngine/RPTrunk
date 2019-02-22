
import Foundation

open class RPGameEnvironment {
    
    // static vars
    static open fileprivate(set) var current:RPGameEnvironment! = RPGameEnvironment(delegate: DefaultGame())
    static fileprivate var environments:[RPGameEnvironment] = []
    
    static open var statTypes:[String] {
       return RPGameEnvironment.current.delegate.statTypes
    }
    
    open var delegate:RPGameDelegate
    
    // static methods
    static open func pushEnvironment(_ env:RPGameEnvironment) {
        RPGameEnvironment.environments.append(env)
        RPGameEnvironment.current = env
    }
    
    static open func popEnvironment() {
        RPGameEnvironment.environments.removeLast()
        RPGameEnvironment.current = RPGameEnvironment.environments.last
    }
    
    // instance methods
    public init(delegate:RPGameDelegate) {
        self.delegate = delegate
    }
    
}

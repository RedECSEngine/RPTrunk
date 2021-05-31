
import Foundation

open class RPGameEnvironment {
    // static vars
    public fileprivate(set) static var current: RPGameEnvironment! = RPGameEnvironment(delegate: DefaultGame())
    fileprivate static var environments: [RPGameEnvironment] = []

    public static var statTypes: Set<String> {
        RPGameEnvironment.current.delegate.statTypes
    }

    open var delegate: RPGameDelegate

    // static methods
    public static func pushEnvironment(_ env: RPGameEnvironment) {
        RPGameEnvironment.environments.append(env)
        RPGameEnvironment.current = env
    }

    public static func popEnvironment() {
        RPGameEnvironment.environments.removeLast()
        RPGameEnvironment.current = RPGameEnvironment.environments.last
    }

    // instance methods
    public init(delegate: RPGameDelegate) {
        self.delegate = delegate
    }
}

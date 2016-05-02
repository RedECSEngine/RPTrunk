
public struct RPStatusEffect: Component {
    
    public let name:String
    public let components:[Component]
    
    //both duration and charge can be used or one or the other
    var duration:Int? //the duration in AP
    var charges:Int? //the number of charges left
    
    public init(name:String, components:[Component], duration:Int?, charges:Int?) {
        self.name = name
        self.components = components
        self.duration = duration
        self.charges = charges
    }
    
    public func getStats() -> RPStats? {
        return nil //stats are only used when applied
    }
    
    public func getTargetType() -> EventTargetType? {
        return nil
    }
    
    public func getCost() -> RPStats? {
        return nil
    }
}

public class RPAppliedStatusEffect {

    var currentTick:Int = 0
    var currentCharge:Int = 0
    
    let ability:Ability
    var level:Int? // power level of the buff, if it is stackable
    var isExpired = false
    
    let statusEffect: RPStatusEffect
    
    public init(_ se: RPStatusEffect) {
        statusEffect = se
        let components:[Component] = se.components + [TargetingComponent(targetType:.Oneself)]
        ability = BasicAbility(name: se.name, components: components)
    }
    
    func tick() {
        
        if let d = statusEffect.duration where d <= currentTick {
            isExpired = true
            return
        }
        currentTick += 1
    }
    
    func expendCharge() {
    
        currentCharge += 1
        if let c = statusEffect.charges where c <= currentCharge {
            isExpired = true
            return
        }
    }
}
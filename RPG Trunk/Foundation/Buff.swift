
public struct Buff: Ability, Component {
    
    public var name:String 
    public var components:[Component] = []
    
    //both duration and charge can be used or one or the other
    var duration:Int? //the duration in AP
    var charges:Int? //the number of charges left
    
//    var isDebuff:Bool = false //positive or negative buff (debuff)?
    
    public func getStats() -> RPStats? {
        return nil // Stats will be used when applied only
    }
    
    public func getEvent(initiator:RPEntity, targets:[RPEntity]) -> Event? {
//        let ab = AppliedBuff(self)
//        return Event(initiator: initiator, targets: [initiator], ability: ab.ability)
        return nil
    }
}

public class AppliedBuff {

    var currentTick:Int = 0
    var currentCharge:Int = 0
    
    let ability:Ability
    var level:Int? // power level of the buff, if it is stackable
    var isExpired = false
    
    let buff:Buff
    
    public init(_ b:Buff) {
        buff = b
        ability = BasicAbility(name: buff.name, components: buff.components, targetType: .Oneself)
    }
    
    func tick() {
        
        if let d = buff.duration where d <= currentTick {
            isExpired = true
            return
        }
        currentTick += 1
    }
    
    func expendCharge() {
    
        currentCharge += 1
        if let c = buff.charges where c <= currentCharge {
            isExpired = true
            return
        }
    }
}
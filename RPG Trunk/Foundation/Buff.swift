
public struct Buff: Component {
    
    public var stats:RPStats = RPStats([:])
    
    //both duration and charge can be used or one or the other
    var duration:Int? //the duration in AP
    var charges:Int? //the number of charges left
    
    var isDebuff:Bool = false //positive or negative buff (debuff)?
}

public struct AppliedBuff {

    var currentTick = 0
    let event:Event?
    var level:Int? // power level of the buff, if it is stackable
    let buff:Buff
}

public struct Body {
    let weapons:[Weapon] = []
    let equipment:[Armor] = []
    let storage = Storage()
}

public class RPEntity: StatsContainer {
    public var baseStats = RPStats([:])
    public var currentStats = RPStats([:], asPartial: true) //when a current is nil, it means it's at max
    
    public var body = Body()
    public var executableAbilities:[Ability] = []
    public var passiveAbilities:[Ability] = []
    public var priorities:[Priority] = []
    public var buffs:[AppliedBuff] = []
    
    public weak var target:RPEntity?
    
    public weak var data:AnyObject?
    
    public var stats:RPStats {
        var totalStats = self.baseStats
        for weapon in self.body.weapons {
            totalStats = totalStats + weapon.stats;
        }
        for equip in self.body.equipment {
            totalStats = totalStats + equip.stats;
        }
        return totalStats
    }
    
    public subscript(index:String) -> RPValue {
        return currentStats.get(index) ?? stats[index]
    }
    
    public func allCurrentStats() -> RPStats {
        var cs:[String:RPValue] = [:]
        let maxStats = stats
        for type in RPGameEnvironment.statTypes {
            cs[type] = currentStats.get(type) ?? maxStats[type]
        }
        return RPStats(cs)
    }
    
    public func setCurrentStats(newStats:RPStats) {
        var cs:[String:RPValue] = [:]
        let maxStats = stats
        for type in RPGameEnvironment.statTypes {
            cs[type] = newStats[type] < maxStats[type] ? newStats[type] : nil
        }
        currentStats = RPStats(cs, asPartial: true)
    }
    
    // Stored on the entity for reuse
    public lazy var parser:Parser<String, PropertyResultType> = {
        return valueParser() <|> entityTargetParser(self) <|> entityStatParser(self)
    }()
    
    public init(_ data:[String:RPValue]) {
        self.baseStats = RPStats(data)
    }
    
    public convenience init() {
        self.init([:])
    }
    
    public func copy() -> RPEntity {
        
        let entity = RPEntity()
        entity.baseStats = self.baseStats
        entity.currentStats = self.currentStats
        entity.body = self.body
        entity.executableAbilities = self.executableAbilities
        entity.passiveAbilities = self.passiveAbilities
        entity.priorities = self.priorities
        entity.buffs = self.buffs
        
        return entity
    }
    
    public func tick() -> [Event] {
        
        var abilityEvents = [Event]()
        for priority in self.priorities where priority.evaluate(self) {
            if let target = self.target {
                abilityEvents.append(Event(initiator: self, targets: [target], ability: priority.ability))
                break
            }
        }
        
        buffs = buffs.filter {
            buff in
            buff.tick()
            return !buff.isExpired
        }
        
        let buffEvents = buffs.map { Event(initiator:self, targets: [self], ability: $0.ability) }
        
        return abilityEvents + buffEvents
    }
    
    func eventWillOccur(event:Event) -> Event? {
        return nil
    }

    func eventDidOccur(event:Event) -> Event? {
        return nil
    }
}

extension RPEntity: CustomStringConvertible {
    
    public var description:String {
        var o:[String:String] = [:]
        let maxStats = stats
        for type in RPGameEnvironment.statTypes {
            o[type] = " \(currentStats.get(type) ?? maxStats[type])/\(maxStats[type])"
        }
        return "Entity:\n " + o.description
    }
    
}


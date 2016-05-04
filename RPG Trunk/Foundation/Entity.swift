
public class RPEntity: StatsContainer {
    
    public var baseStats = RPStats([:])
    public var currentStats = RPStats([:], asPartial: true) //when a current is nil, it means it's at max
    
    public var body = Body()
    public var executableAbilities:[Ability] = []
    public var passiveAbilities:[Ability] = []
    public var priorities:[Priority] = []
    public var statusEffects:[RPAppliedStatusEffect] = []
    
    public var targets:[RPEntity] = []
    public var target:RPEntity? {
        get {
            return targets.first
        }
        set {
            if let v = newValue {
                targets = [v]
                return
            }
            targets = []
        }
    }
    
    public weak var data:AnyObject?
    
    // Stored on the entity for reuse
    public lazy var parser:Parser<String, PropertyResultType> = {
        return valueParser() <|> entityTargetParser(self) <|> entityStatParser(self)
    }()
    
    
    //MARK: - Computed properties
    
    public var stats:RPStats {
        var totalStats = self.baseStats
        for weapon in self.body.weapons {
            totalStats = totalStats + weapon.stats
        }
        for equip in self.body.equipment {
            totalStats = totalStats + equip.stats
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
    
    public func usableAbilities () -> [Ability] {
        
        return executableAbilities.filter {
            let stats = self.allCurrentStats()
            let cost = $0.cost
            
            return self.allCurrentStats() >= $0.cost
        }
    }
    
    
    //MARK: - Initialization
    
    public static func new() -> RPEntity {
        return RPGameEnvironment.current.delegate.entityDefaults.copy()
    }
    
    public init(_ data:[String:RPValue]) {
        self.baseStats = RPStats(data)
    }
    
    public convenience init() {
        self.init([:])
    }
    
    
    //MARK: - RPEvent/Battle handling
    
    public func executeTickAndGetNewEvents() -> [RPEvent] {
        
        // Get any events that should execute based on priorities
        var abilityEvents = [RPEvent]()
        for priority in self.priorities where priority.evaluate(self) {
            if let _ = target {
                abilityEvents.append(RPEvent(initiator: self, ability: priority.ability))
                break
            }
        }
        
        // Next calculate new events that should occur from status effects
        statusEffects = statusEffects.filter {
            se in
            se.tick()
            return !se.isExpired
        }
        
        let buffEvents = statusEffects.map { RPEvent(initiator:self, ability: $0.ability) }
        
        return abilityEvents + buffEvents
    }
    
    func eventWillOccur(event: RPEvent) -> RPEvent? {
        return nil //TODO: Check for passive abilities that would trigger based on this event
    }

    func eventDidOccur(event: RPEvent) -> RPEvent? {
        return nil //TODO: Check for passive abiliies that would trigger etc..
    }
}

extension RPEntity {

    public func copy() -> RPEntity {
        
        let entity = RPEntity()
        entity.baseStats = self.baseStats
        entity.currentStats = self.currentStats
        entity.body = self.body
        entity.executableAbilities = self.executableAbilities
        entity.passiveAbilities = self.passiveAbilities
        entity.priorities = self.priorities
        entity.statusEffects = self.statusEffects
        return entity
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
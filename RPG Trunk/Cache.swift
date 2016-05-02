
public class RPCache {
    
    private enum CacheError:ErrorType {
        case NotFound
        case InvalidFormat(String)
    }
    
    public private(set) static var abilities: [String:Ability] = [:]
    public private(set) static var buffs: [String:RPStatusEffect] = [:]
    public private(set) static var entities: [String:RPEntity] = [:]

    public static func load(data:[String:AnyObject]) throws {

        if let buffs = data["buffs"] as? [String:AnyObject] {
            try RPCache.loadBuffs(buffs)
        }
        
        if let abilities = data["abilities"] as? [String:AnyObject] {
            try RPCache.loadAbilities(abilities)
        }

        if let entities = data["entities"] as? [String:AnyObject] {
            try RPCache.loadEntities(entities)
        }

    }

    public static func loadAbilities(abilities:[String:AnyObject]) throws {

        try abilities.forEach {
            (name, data) in
            
            guard let dict = data as? [String: AnyObject] else {
                throw CacheError.InvalidFormat("Ability should be defined with a dictionary")
            }
            
            let components: [Component] = try dict.flatMap(RPCache.buildComponent)
            
            let ability = BasicAbility(name:name, components:components)
            RPCache.abilities[name] = ability
            
            print("Loaded ability:", name)
        }
    }

    public static func loadBuffs(buffs:[String:AnyObject]) throws {

        try buffs.forEach {
            (name, data) in
            
            guard let dict = data as? [String: AnyObject] else {
                throw CacheError.InvalidFormat("Buff should be defined with a dictionary")
            }
            
            if let stats = dict["stats"] as? [String: RPValue] {
                let duration: Int? = dict["duration"] as? Int
                let charges: Int? = dict["charges"] as? Int
                let buff = RPStatusEffect(name: name, components: [StatsComponent(stats)], duration: duration, charges: charges)
                RPCache.buffs[name] = buff
            }
            
            print("Loaded buff:", name)
        }
    }

    public static func loadEntities(entities:[String:AnyObject]) throws {

        try entities.forEach {
            (name, data) in
            
            guard let dict = data as? [String: AnyObject], let stats = dict["stats"] as? [String:RPValue] else {
                throw CacheError.InvalidFormat("Entities should be defined with a dictionary that includes stats")
            }
            
            let entity = RPEntity(stats)
            RPCache.entities[name] = entity
            
            if let abilities = dict["abilities"] as? [String] {
                abilities.forEach {
                    name in
                    
                    if let ability = RPCache.abilities[name] {
                    
                        entity.executableAbilities.append(ability)
                    }
                }
            }
            
            print("Loaded entity:", name)
        }
    }
    
    public static func buildComponent(component:(String, AnyObject)) throws -> [Component] {
        
        let (key, val) = component
        switch key {
        case "stats":
            guard let stats = val as? [String:RPValue] else {
                throw CacheError.InvalidFormat("stats should be in format of [Key:Value]")
            }
            return [StatsComponent(stats)]
        case "cost":
            guard let cost = val as? [String:RPValue] else {
                throw CacheError.InvalidFormat("cost should be in format of [Key:Value]")
            }
            return [CostComponent(cost)]
        case "components":
            guard let components = val as? [String] else {
                throw CacheError.InvalidFormat("components should be in format of [String]")
            }
            return try components.map { try RPCache.getComponent($0) }
        case "target":
            guard let t = val as? String, let type = EventTargetType(rawValue: t) else {
                throw CacheError.InvalidFormat("invalid target type provided")
            }
            return [TargetingComponent(targetType: type)]
        default:
            return []
        }
    }
    
    public static func getAbility(name: String) throws -> Ability {
        
        if let ability = RPCache.abilities[name] {
            
            return ability
        }
        
        throw RPCache.CacheError.NotFound
    }
    
    public static func getComponent(name: String) throws -> Component {
        
        if let buff = RPCache.buffs[name] {
            
            return buff
        }
        
        throw RPCache.CacheError.NotFound
    }
    
    public static func newEntity(name:String) throws -> RPEntity {
        guard let entity = RPCache.entities[name] else {
            throw RPCache.CacheError.NotFound
        }
        return entity.copy()
    }
    
}


public class RPCache {
    
    public enum CacheError:ErrorType {
        case NotFound(String)
        case InvalidFormat(String)
    }
    
    public private(set) static var abilities: [String:Ability] = [:]
    public private(set) static var statusEffects: [String:StatusEffect] = [:]
    public private(set) static var entities: [String:Entity] = [:]

    public static func load(data:[String:AnyObject]) throws {
        
        print("start loading")

        if let se = data["Status Effects"] as? [String:AnyObject] {
            try RPCache.loadStatusEffects(se)
        }
        
        if let abilities = data["Abilities"] as? [String:AnyObject] {
            try RPCache.loadAbilities(abilities)
        }

        if let entities = data["Entities"] as? [String:AnyObject] {
            try RPCache.loadEntities(entities)
        }
        
        print("done loading")

    }

    public static func loadAbilities(abilities:[String:AnyObject]) throws {

        try abilities.forEach {
            (name, data) in
            
            guard let dict = data as? [String: AnyObject] else {
                throw CacheError.InvalidFormat("Ability should be defined with a dictionary")
            }
            
            let components:[Component] = try dict.flatMap(RPCache.buildComponent)
            
            let ability = Ability(name:name, components:components)
            RPCache.abilities[name] = ability
            
            print("Loaded ability:", name)
        }
    }

    public static func loadStatusEffects(statusEffects:[String:AnyObject]) throws {

        try statusEffects.forEach {
            (name, data) in
            
            guard let dict = data as? [String: AnyObject] else {
                throw CacheError.InvalidFormat("Status effect should be defined with a dictionary")
            }
            
            let components:[Component] = try dict.flatMap(RPCache.buildComponent)
            
            let duration: Double? = dict["duration"] as? Double
            let charges: Int? = dict["charges"] as? Int
            let imapirsAction: Bool = (dict["impairsAction"] as? Bool) ?? false
            
            let id = Identity(name: name)
            let se = StatusEffect(identity: id, components: components, duration: duration, charges: charges, impairsAction: imapirsAction)
            
            RPCache.statusEffects[name] = se
            
            print("Loaded status effect:", name)
        }
    }

    public static func loadEntities(entities:[String:AnyObject]) throws {

        try entities.forEach {
            (name, data) in
            
            guard let dict = data as? [String: AnyObject], let stats = dict["stats"] as? [String:RPValue] else {
                throw CacheError.InvalidFormat("Entities should be defined with a dictionary that includes stats")
            }
            
            let entity = Entity.new()
            entity.baseStats = entity.baseStats + Stats(stats)
            entity.currentStats = entity.currentStats + Stats(stats)
            
            RPCache.entities[name] = entity
            
            if let abilities = dict["abilities"] as? [String] {
                abilities.forEach {
                    name in
                    
                    if let ability = RPCache.abilities[name] {
                    
                        entity.addExecutableAbility(ability, conditional: .Always)
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
            return [Stats(stats)]
        case "cost":
            guard let cost = val as? [String:RPValue] else {
                throw CacheError.InvalidFormat("cost should be in format of [Key:Value]")
            }
            return [BasicComponent(cost:Stats(cost))]
        case "requirements":
            guard let req = val as? [String:RPValue] else {
                throw CacheError.InvalidFormat("cost should be in format of [Key:Value]")
            }
            return [BasicComponent(requirements:Stats(req))]
        case "statusEffects":
            guard let effects = val as? [String] else {
                throw CacheError.InvalidFormat("components should be in format of [String]")
            }
            return try effects.map { try RPCache.getStatusEffect($0) }
        case "target":
            guard let t = val as? String else {
                throw CacheError.InvalidFormat("invalid target type provided")
            }
            let type = Targeting.fromString(t)
            return [type]
        case "discharge":
            guard let r = val as? [String] else {
                throw CacheError.InvalidFormat("invalid discharged status effect format provided; Should be [String]")
            }
            return [BasicComponent(dischargedStatusEffects:r)]
        case "components":
            guard let components = val as? [String] else {
                throw CacheError.InvalidFormat("components should be in format of [String]")
            }
            return try components.map { try RPCache.getComponent($0) }
        default:
            return []
        }
    }
    
    public static func buildConditional(data:[String: AnyObject]) -> Conditional {
        
        if let query = data["conditional"] as? String {
            return Conditional(query)
        }
        
        return .Always
    }
    
    public static func getAbility(name: String) throws -> Ability {
        
        if let ability = RPCache.abilities[name] {
            
            return ability
        }
        
        throw RPCache.CacheError.NotFound(name)
    }
    
    public static func getStatusEffect(name: String) throws -> Component {
        
        if let se = RPCache.statusEffects[name] {
            
            return se
        }
        
        throw RPCache.CacheError.NotFound(name)
    }
    
    public static func getComponent(name: String) throws -> Component {
        
        //TODO: expand this function to try other types of components before throwing an error
        
        guard let se = try? RPCache.getStatusEffect(name) else {
            throw RPCache.CacheError.NotFound(name)
        }
        
        return se
    }
    
    public static func newEntity(name:String) throws -> Entity {
        guard let entity = RPCache.entities[name] else {
            throw RPCache.CacheError.NotFound(name)
        }
        return entity.copy()
    }
    
}

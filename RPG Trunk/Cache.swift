
open class RPCache {
    
    public enum CacheError:Error {
        case notFound(String)
        case invalidFormat(String)
    }
    
    open fileprivate(set) static var abilities: [String:Ability] = [:]
    open fileprivate(set) static var statusEffects: [String:StatusEffect] = [:]
    open fileprivate(set) static var entities: [String:Entity] = [:]

    open static func load(_ data:[String:AnyObject]) throws {
        
        print(String(describing: self), ">> start loading")

        if let se = data["Status Effects"] as? [String:AnyObject] {
            try RPCache.loadStatusEffects(se)
        }
        
        if let abilities = data["Abilities"] as? [String:AnyObject] {
            try RPCache.loadAbilities(abilities)
        }

        if let entities = data["Entities"] as? [String:AnyObject] {
            try RPCache.loadEntities(entities)
        }
        
        print(String(describing: self), ">> done loading")

    }

    open static func loadAbilities(_ abilities:[String:AnyObject]) throws {

        try abilities.forEach {
            (arg) in
            let (name, data) = arg
            
            guard let dict = data as? [String: AnyObject] else {
                throw CacheError.invalidFormat("Ability should be defined with a dictionary")
            }
            
            let components:[Component] = try dict.flatMap(RPCache.buildComponent)
            
            let cooldown: RPTimeIncrement? = dict["cooldown"] as? RPTimeIncrement
            
            let ability = Ability(name:name, components:components, cooldown: cooldown)
            RPCache.abilities[name] = ability
            
            print("Loaded ability:", name)
        }
    }

    open static func loadStatusEffects(_ statusEffects:[String:AnyObject]) throws {

        try statusEffects.forEach {
            (arg) in
            let (name, data) = arg
            
            guard let dict = data as? [String: AnyObject] else {
                throw CacheError.invalidFormat("Status effect should be defined with a dictionary")
            }
            
            let components:[Component] = try dict.flatMap(RPCache.buildComponent)
            
            let duration: Double? = dict["duration"] as? RPTimeIncrement
            let charges: Int? = dict["charges"] as? Int
            let impairsAction: Bool = (dict["impairsAction"] as? Bool) ?? false
            
            let id = Identity(name: name)
            let se = StatusEffect(identity: id, components: components, duration: duration, charges: charges, impairsAction: impairsAction)
            
            RPCache.statusEffects[name] = se
            
            print("Loaded status effect:", name)
        }
    }

    open static func loadEntities(_ entities:[String:AnyObject]) throws {

        try entities.forEach {
            (arg) in
            let (name, data) = arg
            
            guard let dict = data as? [String: AnyObject], let stats = dict["stats"] as? [String:RPValue] else {
                throw CacheError.invalidFormat("Entities should be defined with a dictionary that includes stats")
            }
            
            let entity = Entity.new()
            entity.baseStats = entity.baseStats + Stats(stats)
            entity.currentStats = entity.currentStats + Stats(stats)
            
            RPCache.entities[name] = entity
            
            if let abilities = dict["abilities"] as? [String] {
                abilities.forEach {
                    name in
                    
                    if let ability = RPCache.abilities[name] {
                    
                        entity.addExecutableAbility(ability, conditional: .always)
                    }
                }
            }
            
            print("Loaded entity:", name)
        }
    }
    
    open static func buildComponent(_ component:(String, AnyObject)) throws -> [Component] {
        
        let (key, val) = component
        switch key {
        case "stats":
            guard let stats = val as? [String:RPValue] else {
                throw CacheError.invalidFormat("stats should be in format of [Key:Value]")
            }
            return [Stats(stats)]
        case "cost":
            guard let cost = val as? [String:RPValue] else {
                throw CacheError.invalidFormat("cost should be in format of [Key:Value]")
            }
            return [BasicComponent(cost:Stats(cost))]
        case "requirements":
            guard let req = val as? [String:RPValue] else {
                throw CacheError.invalidFormat("cost should be in format of [Key:Value]")
            }
            return [BasicComponent(requirements:Stats(req))]
        case "statusEffects":
            guard let effects = val as? [String] else {
                throw CacheError.invalidFormat("components should be in format of [String]")
            }
            return try effects.map { try RPCache.getStatusEffect($0) }
        case "target":
            guard let t = val as? String else {
                throw CacheError.invalidFormat("invalid target type provided")
            }
            let type = Targeting.fromString(t)
            return [type]
        case "discharge":
            guard let r = val as? [String] else {
                throw CacheError.invalidFormat("invalid discharged status effect format provided; Should be [String]")
            }
            return [BasicComponent(dischargedStatusEffects:r)]
        case "components":
            guard let components = val as? [String] else {
                throw CacheError.invalidFormat("components should be in format of [String]")
            }
            return try components.map { try RPCache.getComponent($0) }
        default:
            return []
        }
    }
    
    open static func buildConditional(_ data:[String: AnyObject]) -> Conditional {
        
        if let query = data["conditional"] as? String {
            return Conditional(query)
        }
        
        return .always
    }
    
    open static func getAbility(_ name: String) throws -> Ability {
        
        if let ability = RPCache.abilities[name] {
            
            return ability
        }
        
        throw RPCache.CacheError.notFound(name)
    }
    
    open static func getStatusEffect(_ name: String) throws -> Component {
        
        if let se = RPCache.statusEffects[name] {
            
            return se
        }
        
        throw RPCache.CacheError.notFound(name)
    }
    
    open static func getComponent(_ name: String) throws -> Component {
        
        //TODO: expand this function to try other types of components before throwing an error
        
        guard let se = try? RPCache.getStatusEffect(name) else {
            throw RPCache.CacheError.notFound(name)
        }
        
        return se
    }
    
    open static func newEntity(_ name:String) throws -> Entity {
        guard let entity = RPCache.entities[name] else {
            throw RPCache.CacheError.notFound(name)
        }
        return entity.copy()
    }
    
}

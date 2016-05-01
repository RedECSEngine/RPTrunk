
public class RPCache {
    
    private enum CacheError:ErrorType {
        case NotFound
    }
    
    public private(set) static var abilities: [String:Ability] = [:]
    public private(set) static var buffs: [String:Buff] = [:]
    public private(set) static var entities: [String:RPEntity] = [:]

    public static func load(data:[String:AnyObject]) {

        if let abilities = data["abilities"] as? [String:AnyObject] {
            RPCache.loadAbilities(abilities)
        }

        if let buffs = data["buffs"] as? [String:AnyObject] {
            RPCache.loadBuffs(buffs)
        }

        if let entities = data["entities"] as? [String:AnyObject] {
            RPCache.loadEntities(entities)
        }

    }

    public static func loadAbilities(abilities:[String:AnyObject]) {

        abilities.forEach {
            (name, data) in
            
            if let stats = data["stats"] as? [String: RPValue] {
                let component = StatsComponent(stats)
                let ability = BasicAbility(name:name, components:[component], targetType: .SingleEnemy)
                RPCache.abilities[name] = ability
            }
            
            print("Loaded ability:", name)
        }
    }

    public static func loadBuffs(buffs:[String:AnyObject]) {

        buffs.forEach {
            (name, data) in
            
            if let stats = data["stats"] as? [String: RPValue] {
                let duration: Int? = data["duration"] as? Int
                let charges: Int? = data["charges"] as? Int
                let buff = Buff(name: name, components: [StatsComponent(stats)], duration: duration, charges: charges)
                RPCache.buffs[name] = buff
            }
            
            print("Loaded buff:", name)
        }
    }

    public static func loadEntities(entities:[String:AnyObject]) {

        entities.forEach {
            (name, data) in
            
            guard let stats = data["stats"] as? [String: RPValue] else {
                return
            }
            
            let entity = RPEntity(stats)
            RPCache.entities[name] = entity
            
            if let abilities = data["abilities"] as? [String] {
                abilities.forEach {
                    name in
                    
                    if let ability = RPCache.abilities[name] {
                    
                        entity.executableAbilities.append(ability)
                    }
                    if let buff = RPCache.buffs[name] {
                        
                        entity.executableAbilities.append(buff)
                    }
                    
                }
            }
            
            print("Loaded entity:", name)
        }
    }
    
    public static func getAbility(name: String) throws -> Ability {
        
        if let ability = RPCache.abilities[name] {
            
            return ability
        }
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

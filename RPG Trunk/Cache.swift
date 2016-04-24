
public class RPCache {
    
    private enum CacheError:ErrorType {
        case NotFound
    }
    
    public private(set) static var abilities: [String:Ability] = [:]
    public private(set) static var entities: [String:RPEntity] = [:]

    public static func load(data:[String:AnyObject]) {

        if let abilities = data["abilities"] as? [String:AnyObject] {
            RPCache.loadAbilities(abilities)
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
                let ability = Ability(name:name, components:[component])
                RPCache.abilities[name] = ability
            }
            
            print("Loaded ability:", name)
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
                    let ability = RPCache.abilities[name]!
                    let priority = Priority(ability: ability, conditionals: nil)
                    entity.priorities.append(priority)
                }
            }
            
            print("Loaded entity:", name)
        }
    }
    
    public static func newEntity(name:String) throws -> RPEntity {
        guard let entity = RPCache.entities[name] else {
            throw RPCache.CacheError.NotFound
        }
        return entity.copy()
    }

}

open enum RPCache {
    public enum CacheError: Error {
        case notFound(String)
        case invalidFormat(String)
    }

    public fileprivate(set) static var abilities: [String: Ability] = [:]
    public fileprivate(set) static var statusEffects: [String: StatusEffect] = [:]
    public fileprivate(set) static var entities: [String: Entity] = [:]

    public static func load(_ data: [String: AnyObject]) throws {
        if let se = data["Status Effects"] as? [String: AnyObject] {
            try RPCache.loadStatusEffects(se)
        }

        if let abilities = data["Abilities"] as? [String: AnyObject] {
            try RPCache.loadAbilities(abilities)
        }

        if let entities = data["Entities"] as? [String: AnyObject] {
            try RPCache.loadEntities(entities)
        }

        // TODO: Handle items
    }

    public static func loadAbilities(_ abilities: [String: AnyObject]) throws {
        try abilities.forEach {
            arg in
            let (name, data) = arg

            guard let dict = data as? [String: AnyObject] else {
                throw CacheError.invalidFormat("Ability should be defined with a dictionary")
            }

            let components: [Component] = try dict.flatMap(RPCache.buildComponent)

            let cooldown: RPTimeIncrement? = dict["cooldown"] as? RPTimeIncrement

            var ability = Ability(name: name, components: components, cooldown: cooldown)
            ability.metadata = dict.filter { $0.value is String } as? [String: String]

            RPCache.abilities[name] = ability
        }
    }

    public static func loadStatusEffects(_ statusEffects: [String: AnyObject]) throws {
        try statusEffects.forEach {
            arg in
            let (name, data) = arg

            guard let dict = data as? [String: AnyObject] else {
                throw CacheError.invalidFormat("Status effect should be defined with a dictionary")
            }

            let components: [Component] = try dict.flatMap(RPCache.buildComponent)

            let duration: Double? = dict["duration"] as? RPTimeIncrement
            let charges: Int? = dict["charges"] as? Int
            let impairsAction: Bool = (dict["impairsAction"] as? Bool) ?? false

            let id = Identity(name: name)
            let se = StatusEffect(identity: id, components: components, duration: duration, charges: charges, impairsAction: impairsAction)

            RPCache.statusEffects[name] = se
        }
    }

    public static func loadEntities(_ entities: [String: AnyObject]) throws {
        try entities.forEach {
            arg in
            let (name, data) = arg

            guard let dict = data as? [String: AnyObject] else {
                throw CacheError.invalidFormat("Entities should be defined with a dictionary that includes stats")
            }

            let stats: [String: RPValue] = (dict["stats"] as? [String: RPValue]) ?? [:]

            let entity = Entity.new()
            entity.baseStats = entity.baseStats + Stats(stats)
            entity.currentStats = entity.currentStats + Stats(stats)

            RPCache.entities[name] = entity

            if let abilities = dict["abilities"] as? [[String: AnyObject]] {
                abilities.forEach {
                    dict in

                    guard let name = dict["name"] as? String,
                          let conditionalString = dict["conditional"] as? String
                    else {
                        return
                    }

                    let conditional = Conditional(conditionalString)
                    if let ability = RPCache.abilities[name] {
                        entity.addExecutableAbility(ability, conditional: conditional)
                    }
                }
            }
        }
    }

    public static func buildComponent(_ component: (String, AnyObject)) throws -> [Component] {
        let (key, val) = component
        switch key {
        case "stats":
            guard let stats = val as? [String: RPValue] else {
                throw CacheError.invalidFormat("stats should be in format of [Key:Value]")
            }
            return [Component(stats: Stats(stats))]
        case "cost":
            guard let cost = val as? [String: RPValue] else {
                throw CacheError.invalidFormat("cost should be in format of [Key:Value]")
            }
            return [Component(cost: Stats(cost))]
        case "requirements":
            guard let req = val as? [String: RPValue] else {
                throw CacheError.invalidFormat("cost should be in format of [Key:Value]")
            }
            return [Component(requirements: Stats(req))]
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
            return [Component(targetType: type)]
        case "discharge":
            guard let r = val as? [String] else {
                throw CacheError.invalidFormat("invalid discharged status effect format provided; Should be [String]")
            }
            return [Component(dischargedStatusEffects: r)]
        case "components":
            guard let components = val as? [String] else {
                throw CacheError.invalidFormat("components should be in format of [String]")
            }
            return try components.map { try RPCache.getComponent($0) }
        default:
            return []
        }
    }

    public static func buildConditional(_ data: [String: AnyObject]) -> Conditional {
        if let query = data["conditional"] as? String {
            return Conditional(query)
        }

        return .always
    }

    public static func getAbility(_ name: String) throws -> Ability {
        if let ability = RPCache.abilities[name] {
            return ability
        }

        throw RPCache.CacheError.notFound(name)
    }

    public static func getStatusEffect(_ name: String) throws -> Component {
        if let se = RPCache.statusEffects[name] {
            return Component(statusEffects: [se])
        }

        throw RPCache.CacheError.notFound(name)
    }

    public static func getComponent(_ name: String) throws -> Component {
        // TODO: expand this function to try other types of components before throwing an error

        guard let se = try? RPCache.getStatusEffect(name) else {
            throw RPCache.CacheError.notFound(name)
        }

        return se
    }

    public static func newEntity(_ name: String) throws -> Entity {
        guard let entity = RPCache.entities[name] else {
            throw RPCache.CacheError.notFound(name)
        }
        return entity.copy()
    }
}

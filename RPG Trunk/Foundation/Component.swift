
public protocol Component {
    
    func getStats() -> Stats?
    func getCost() -> Stats?
    func getRequirements() -> Stats?
    func getTargeting() -> Targeting?
    func getStatusEffects() -> [StatusEffect]
    func getDischargedStatusEffects() -> [String]
    func getItemExchange() -> ItemExchange?
}

public protocol ComponentContainer {
    var components: [Component] { get }
}

extension ComponentContainer {

    public var stats: Stats {
        
        return components
            .flatMap { $0.getStats() }
            .reduce(Stats(), +)
    }

    public var cost: Stats {
        
        return components
            .flatMap { $0.getCost() }
            .reduce(Stats(), +)
    }

    public var requirements: Stats {
        
        return components
            .flatMap { $0.getRequirements() }
            .reduce(Stats(), +)
    }

    public var targeting: Targeting {

        for component in components {
            if let t = component.getTargeting() {
                return t
            }
        }
        return Targeting(.singleEnemy, .always)
    }

    public var statusEffects: [StatusEffect] {
        return components
            .flatMap { $0.getStatusEffects() }
    }

    public var dischargedStatusEffects: [String] {
        return components
            .flatMap { $0.getDischargedStatusEffects() }
    }
    
    public var itemExchange: ItemExchange? {
        
        for component in components {
            if let exchange = component.getItemExchange() {
                return exchange
            }
        }
        return nil
    }
}

func ==(a:ComponentContainer, b:ComponentContainer) -> Bool {
    return a.stats == b.stats
        && a.cost == b.cost
        && a.requirements == b.requirements
        && a.targeting == b.targeting
        && a.statusEffects == b.statusEffects
        && a.dischargedStatusEffects == b.dischargedStatusEffects
 }

public struct BasicComponent: Component {
    
    fileprivate struct IntermediaryContainer: ComponentContainer {
        let components: [Component]
    }

    public var stats: Stats?
    public var cost: Stats?
    public var requirements: Stats?
    public var targeting:Targeting?
    public var statusEffects: [StatusEffect]?
    public var dischargedStatusEffects: [String]?
    public var itemExchange: ItemExchange?
    
    public init(stats: Stats) {
        self.stats = stats
    }
    
    public init(cost: Stats) {
        self.cost = cost
    }
    
    public init(requirements: Stats) {
        self.requirements = requirements
    }
    
    public init(targetType: Targeting) {
        self.targeting = targetType
    }
    
    public init(statusEffects: [StatusEffect]) {
        self.statusEffects = statusEffects
    }
    
    public init(dischargedStatusEffects: [String]) {
        self.dischargedStatusEffects = dischargedStatusEffects
    }
    
    public init(itemExchange: ItemExchange) {
        self.itemExchange = itemExchange
    }
    
    public init(flattenedFrom components: [Component]) {
        
        let container = IntermediaryContainer(components: components)
        
        self.stats = container.stats
        self.cost = container.cost
        self.requirements = container.requirements
        self.targeting = container.targeting
        self.statusEffects = container.statusEffects
        self.dischargedStatusEffects = container.dischargedStatusEffects
        self.itemExchange = container.itemExchange
    }
    
    public func getStats() -> Stats? { return stats }
    public func getCost() -> Stats? { return cost }
    public func getRequirements() -> Stats? { return requirements }
    public func getTargeting() -> Targeting? { return targeting }
    public func getStatusEffects() -> [StatusEffect] { return statusEffects ?? [] }
    public func getDischargedStatusEffects() -> [String] { return dischargedStatusEffects ?? [] }
    public func getItemExchange() -> ItemExchange? { return itemExchange }
    
}

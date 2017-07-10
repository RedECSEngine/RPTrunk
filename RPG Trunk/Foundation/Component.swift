
public protocol Component {
    
    func getStats() -> Stats?
    func getCost() -> Stats?
    func getRequirements() -> Stats?
    func getTargeting() -> Targeting?
    func getStatusEffects() -> [StatusEffect]
    func getDischargedStatusEffects() -> [String]
}

extension Component {
    public func getStats() -> Stats? {
        return nil
    }
    
    public func getTargeting() -> Targeting? {
        return nil
    }
    
    public func getCost() -> Stats? {
        return nil
    }
    
    public func getRequirements() -> Stats? {
        return nil
    }
    
    public func getStatusEffects() -> [StatusEffect] {
        return []
    }
    
    public func getDischargedStatusEffects() -> [String] {
        return []
    }
}

public protocol ComponentContainer {
    var components:[Component] { get }
}

extension ComponentContainer {

    public var stats:Stats {
        
        return components
            .flatMap { $0.getStats() }
            .reduce(Stats(), +)
    }

    public var cost:Stats {
        
        return components
            .flatMap { $0.getCost() }
            .reduce(Stats(), +)
    }

    public var requirements:Stats {
        
        return components
            .flatMap { $0.getRequirements() }
            .reduce(Stats(), +)
    }

    public var targeting:Targeting {

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

    public var dischargedStatusEffects:[String] {
        return components
            .flatMap { $0.getDischargedStatusEffects() }
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

    public let stats: Stats?
    public let cost: Stats?
    public let requirements: Stats?
    public let targeting:Targeting?
    public let statusEffects: [StatusEffect]?
    public let dischargedStatusEffects: [String]?
    
    public init(stats: Stats) {
        self.stats = stats
        self.cost = nil
        self.requirements = nil
        self.targeting = nil
        self.statusEffects = nil
        self.dischargedStatusEffects = nil
    }
    
    public init(cost: Stats) {
        self.stats = nil
        self.cost = cost
        self.requirements = nil
        self.targeting = nil
        self.statusEffects = nil
        self.dischargedStatusEffects = nil
    }
    
    public init(requirements: Stats) {
        self.stats = nil
        self.cost = nil
        self.requirements = requirements
        self.targeting = nil
        self.statusEffects = nil
        self.dischargedStatusEffects = nil
    }
    
    public init(targetType:Targeting) {
        self.stats = nil
        self.cost = nil
        self.requirements = nil
        self.targeting = targetType
        self.statusEffects = nil
        self.dischargedStatusEffects = nil
    }
    
    public init(statusEffects:[StatusEffect]) {
        self.stats = nil
        self.cost = nil
        self.requirements = nil
        self.targeting = nil
        self.statusEffects = statusEffects
        self.dischargedStatusEffects = nil
    }
    
    public init(dischargedStatusEffects:[String]) {
        self.stats = nil
        self.cost = nil
        self.requirements = nil
        self.targeting = nil
        self.statusEffects = nil
        self.dischargedStatusEffects = dischargedStatusEffects
    }
    
    public init(fromComponents:[Component]) {
        
        let container = IntermediaryContainer(components:fromComponents)
        
        self.stats = container.stats
        self.cost = container.cost
        self.requirements = container.requirements
        self.targeting = container.targeting
        self.statusEffects = container.statusEffects
        self.dischargedStatusEffects = container.dischargedStatusEffects
    }
    
    public func getStats() -> Stats? { return stats }
    public func getCost() -> Stats? { return cost }
    public func getRequirements() -> Stats? { return requirements }
    public func getTargeting() -> Targeting? { return targeting }
    public func getStatusEffects() -> [StatusEffect] { return statusEffects ?? [] }
    public func getDischargedStatusEffects() -> [String] { return dischargedStatusEffects ?? [] }
    
}


public protocol Component {
    
    func getStats() -> Stats?
    func getCost() -> Stats?
    func getRequirements() -> Stats?
    func getTargetType() -> TargetType?
    func getStatusEffects() -> [StatusEffect]
    func getDischargedStatusEffects() -> [String]
}

extension Component {
    public func getStats() -> Stats? {
        return nil
    }
    
    public func getTargetType() -> TargetType? {
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

func combineComponentStats(components:[Component]) -> Stats {
    
    return components
        .flatMap { $0.getStats() }
        .reduce(Stats(), combine: +)
}

func combineComponentCosts(components:[Component]) -> Stats {
    
    return components
        .flatMap { $0.getCost() }
        .reduce(Stats(), combine: +)
}

func combineComponentRequirements(components:[Component]) -> Stats {
    
    return components
        .flatMap { $0.getRequirements() }
        .reduce(Stats(), combine: +)
}

func combineComponentTargetTypes(components:[Component]) -> TargetType {

    for component in components {
        if let t = component.getTargetType() {
            return t
        }
    }
    return .SingleEnemy
}

func combineComponentStatusEffects(components:[Component]) -> [StatusEffect] {
    return components
        .flatMap { $0.getStatusEffects() }
}

func combineComponentDischargedStatusEffects(components:[Component]) -> [String] {
    return components
        .flatMap { $0.getDischargedStatusEffects() }
}

func componentsAreEqual(a:[Component], _ b:[Component]) -> Bool {
    return combineComponentStats(a) == combineComponentStats(b)
        && combineComponentCosts(a) == combineComponentCosts(b)
        && combineComponentRequirements(a) == combineComponentRequirements(b)
        && combineComponentTargetTypes(a) == combineComponentTargetTypes(b)
        && combineComponentStatusEffects(a) == combineComponentStatusEffects(b)
        && combineComponentDischargedStatusEffects(a) == combineComponentDischargedStatusEffects(b)
 }

public struct BasicComponent: Component {

    public let stats: Stats?
    public let cost: Stats?
    public let requirements: Stats?
    public let targetType:TargetType?
    public let statusEffects: [StatusEffect]?
    public let dischargedStatusEffects: [String]?
    
    public init(stats: Stats) {
        self.stats = stats
        self.cost = nil
        self.requirements = nil
        self.targetType = nil
        self.statusEffects = nil
        self.dischargedStatusEffects = nil
    }
    
    public init(cost: Stats) {
        self.stats = nil
        self.cost = cost
        self.requirements = nil
        self.targetType = nil
        self.statusEffects = nil
        self.dischargedStatusEffects = nil
    }
    
    public init(requirements: Stats) {
        self.stats = nil
        self.cost = nil
        self.requirements = requirements
        self.targetType = nil
        self.statusEffects = nil
        self.dischargedStatusEffects = nil
    }
    
    public init(targetType:TargetType) {
        self.stats = nil
        self.cost = nil
        self.requirements = nil
        self.targetType = targetType
        self.statusEffects = nil
        self.dischargedStatusEffects = nil
    }
    
    public init(statusEffects:[StatusEffect]) {
        self.stats = nil
        self.cost = nil
        self.requirements = nil
        self.targetType = nil
        self.statusEffects = statusEffects
        self.dischargedStatusEffects = nil
    }
    
    public init(dischargedStatusEffects:[String]) {
        self.stats = nil
        self.cost = nil
        self.requirements = nil
        self.targetType = nil
        self.statusEffects = nil
        self.dischargedStatusEffects = dischargedStatusEffects
    }
    
    public init(fromComponents:[Component]) {
        
        self.stats = combineComponentStats(fromComponents)
        self.cost = combineComponentCosts(fromComponents)
        self.requirements = combineComponentRequirements(fromComponents)
        self.targetType = combineComponentTargetTypes(fromComponents)
        self.statusEffects = combineComponentStatusEffects(fromComponents)
        self.dischargedStatusEffects = combineComponentDischargedStatusEffects(fromComponents)
    }
    
    public func getStats() -> Stats? { return stats }
    public func getCost() -> Stats? { return cost }
    public func getRequirements() -> Stats? { return requirements }
    public func getTargetType() -> TargetType? { return targetType }
    public func getStatusEffects() -> [StatusEffect] { return statusEffects ?? [] }
    public func getDischargedStatusEffects() -> [String] { return dischargedStatusEffects ?? [] }
    
}

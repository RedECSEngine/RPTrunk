import Foundation

public struct ItemExchange {
    
    public enum ExchangeType: String {
        case target
        case targetTeam
        case rpSpace
    }
    
    public let exchangeType: ExchangeType
    public let requiresInitiatorOwnItem: Bool
    public let removesItemFromInitiator: Bool
    public let item: Storable
}

extension ItemExchange: Component {
    
    public func getTargeting() -> Targeting? {
        return nil
    }
    
    public func getStats() -> Stats? {
        return nil
    }
    
    public func getCost() -> Stats? {
        return nil
    }
    
    public func getRequirements() -> Stats? {
        return nil
    }
    
    public func getDischargedStatusEffects() -> [String] {
        return []
    }
    
    public func getStatusEffects() -> [StatusEffect] {
        return []
    }
    
    public func getItemExchange() -> ItemExchange? {
        return self
    }
}

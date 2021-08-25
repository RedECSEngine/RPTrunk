import Foundation
/*
     Situations to handle

     - collect and immediately consume item
     - collect and store item
     - exchange item between entities (trade, steal, drop)
     - use item, to initiate an ability
 */
public struct ItemExchange: Codable, Equatable {
    public enum ExchangeType: String, Codable, Equatable {
        case target
        case targetTeam
    }

    public let exchangeType: ExchangeType
    public let requiresInitiatorOwnItem: Bool
    public let removesItemFromInitiator: Bool
    public let item: RPItemId
    
    public init(
        exchangeType: ItemExchange.ExchangeType,
        requiresInitiatorOwnItem: Bool,
        removesItemFromInitiator: Bool,
        item: RPItemId
    ) {
        self.exchangeType = exchangeType
        self.requiresInitiatorOwnItem = requiresInitiatorOwnItem
        self.removesItemFromInitiator = removesItemFromInitiator
        self.item = item
    }
}

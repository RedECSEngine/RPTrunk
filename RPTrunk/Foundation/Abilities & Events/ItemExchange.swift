import Foundation
/*
     Situations to handle
 
     - collect and immediately consume item
     - collect and store item
     - exchange item between entities (trade, steal, drop)
     - use item, to initiate an ability
 */
public struct ItemExchange: Codable {
    
    public enum ExchangeType: String, Codable {
        case target
        case targetTeam
        case rpSpace
    }
    
    public let exchangeType: ExchangeType
    public let requiresInitiatorOwnItem: Bool
    public let removesItemFromInitiator: Bool
    public let item: Item
}

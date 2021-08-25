import Foundation
@testable import RPTrunk

public struct TestStats: StatsType {
    enum CodingKeys: String, CodingKey {
        case hp, mana, damage, agility
    }
    
    public var hp: Int = 0
    public var mana: Int = 0
    public var damage: Int = 0
    public var agility: Int = 0
    
    public static var dynamicKeys: [String : WritableKeyPath<TestStats, Int>] = [
        "hp": \.hp,
        "mana": \.mana,
        "damage": \.damage,
        "agility": \.agility
    ]
    
    public static var numericAndComparableKeys: [WritableKeyPath<TestStats, Int>] = [
        \.hp,
        \.mana,
        \.damage,
        \.agility
    ]
    
    public init() {}
}

@testable import RPTrunk

@StatsStruct
public struct TestStats {
    enum CodingKeys: String, CodingKey {
        case hp, mana, damage, agility
    }

    public var hp: Int = 0
    public var mana: Int = 0
    public var damage: Int = 0
    public var agility: Int = 0
}

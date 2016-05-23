
public enum TargetType:String, Component {
    
    //In use
    case Oneself = "self"
    case SingleEnemy = "enemy"
    case All = "all"
    
    //Currently unused
    case Random = "random"
    case AllFriendly = "allFriendlies"
    case AllEnemy = "allEnemies"
    case GroupFriendly = "someFriendlies"
    case GroupEnemy = "someEnemies"
    case SingleFriendly = "ally"
    case RandomFriendly = "randomFriendly"
    case RandomEnemy = "randomEnemy"
    
    public func getTargetType() -> TargetType? {
        return self
    }
}
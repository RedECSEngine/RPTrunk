public enum RPTriggerSource: Codable, Equatable, Hashable {
    case body
    case statusEffect(RPReferenceCode)
}

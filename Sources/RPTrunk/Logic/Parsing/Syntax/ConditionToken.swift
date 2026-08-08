public enum ConditionToken: Equatable {
    case target
    case oneself
    case tagQuery(TagDomain, TagMode, [String])
    case threat
    case keyword(String, usePercent: Bool)
    case value(RPValue)
    case percent(Double)

    public enum TagDomain: String, Equatable {
        case has
        case uses
        case holds
    }

    public enum TagMode: String, Equatable {
        case any = "Any"
        case all = "All"
    }
}

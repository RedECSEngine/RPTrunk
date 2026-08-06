/// One term in a dot-notation chain, e.g. `target`, `hp%`, `has`, `40`, `10%`.
public enum ConditionToken: Equatable {
    case target
    case oneself
    case has
    case uses
    case threat
    case keyword(String, usePercent: Bool)
    case value(RPValue)
    case percent(Double)
}

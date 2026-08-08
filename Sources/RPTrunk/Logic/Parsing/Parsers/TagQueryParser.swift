func getTagQuery<RP: RPSpace>(
    _ domain: ConditionToken.TagDomain,
    _ mode: ConditionToken.TagMode,
    _ tags: [String]
) -> (ParserResultType<RP>, RPConditionContext, RP) -> ParserResultType<RP> {
    { input, _, rpSpace in
        guard case let .bodyResult(e) = input else {
            return .nothing
        }
        guard let body = rpSpace.bodyById(e) else {
            return .valueResult(.bool(false))
        }
        let matches: (String) -> Bool
        switch domain {
        case .has:
            matches = { body.hasStatus(RPStatusTag($0)) }
        case .uses:
            matches = { body.usesAnyAbility(tagged: RPAbilityTag($0)) }
        case .holds:
            matches = { body.holdsAnyItem(tagged: RPItemTag($0)) }
        }
        let found = mode == .any ? tags.contains(where: matches) : tags.allSatisfy(matches)
        return .valueResult(.bool(found))
    }
}

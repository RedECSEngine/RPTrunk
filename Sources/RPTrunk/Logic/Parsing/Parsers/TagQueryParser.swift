func getTagQuery<RP: RPSpace>(
    _ domain: ConditionToken.TagDomain,
    _ mode: ConditionToken.TagMode,
    _ tags: [String]
) -> (ParserResultType<RP>, RPConditionContext, RP) -> ParserResultType<RP> {
    let query: (RPBody<RP>) -> Bool
    switch (domain, mode) {
    case (.status, .any):
        let tagSet = Set(tags.map(RPStatusTag.init))
        query = { $0.hasAnyStatus(tagged: tagSet) }
    case (.status, .all):
        let tagSet = Set(tags.map(RPStatusTag.init))
        query = { $0.hasAllStatuses(tagged: tagSet) }
    case (.uses, .any):
        let tagSet = Set(tags.map(RPAbilityTag.init))
        query = { $0.usesAnyAbility(tagged: tagSet) }
    case (.uses, .all):
        let tagSet = Set(tags.map(RPAbilityTag.init))
        query = { $0.usesAllAbilities(tagged: tagSet) }
    case (.holds, .any):
        let tagSet = Set(tags.map(RPItemTag.init))
        query = { $0.holdsAnyItem(tagged: tagSet) }
    case (.holds, .all):
        let tagSet = Set(tags.map(RPItemTag.init))
        query = { $0.holdsAllItems(tagged: tagSet) }
    }
    return { input, _, rpSpace in
        guard case let .bodyResult(e) = input else {
            return .nothing
        }
        guard let body = rpSpace.bodyById(e) else {
            return .valueResult(.bool(false))
        }
        return .valueResult(.bool(query(body)))
    }
}

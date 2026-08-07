func getHoldsItemTag<RP: RPSpace>(_ tag: String) -> (ParserResultType<RP>, RPConditionContext, RP) -> ParserResultType<RP> {
    { input, _, rpSpace in
        if case let .bodyResult(e) = input {
            let found = rpSpace.bodyById(e)?.holdsAnyItem(tagged: RPItemTag(tag)) == true
            return .valueResult(.bool(found))
        }
        return .nothing
    }
}

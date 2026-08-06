func getThreat<RP: RPSpace>() -> (ParserResultType<RP>, RPConditionContext, RP) -> ParserResultType<RP> {
    { input, context, rpSpace in
        if case let .bodyResult(e) = input, let initiator = rpSpace.bodyById(context.initiator) {
            return .valueResult(.value(initiator.threat[e] ?? 0))
        }
        return .nothing
    }
}

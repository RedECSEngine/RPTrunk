//
//  TargetParser.swift
//
//
//  Created by Kyle Newsome on 2021-05-31.
//


func getTarget<RP: RPSpace>(
    _ input: ParserResultType<RP>,
    _ context: RPConditionContext,
    in rpSpace: RP
) -> ParserResultType<RP> {
    if case let .bodyResult(e) = input, let target = rpSpace.bodyById(e)?.threatList.first?.bodyId {
        return .bodyResult(body: target)
    }
    return .nothing
}

func getInitiator<RP: RPSpace>() -> (ParserResultType<RP>, RPConditionContext, RP) -> ParserResultType<RP> {
    { _, context, _ in .bodyResult(body: context.initiator) }
}

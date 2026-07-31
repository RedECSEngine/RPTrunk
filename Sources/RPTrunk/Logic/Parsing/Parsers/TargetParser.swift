//
//  TargetParser.swift
//  
//
//  Created by Kyle Newsome on 2021-05-31.
//


func getTarget<RP: RPSpace>(
    _ input: ParserResultType<RP>,
    in rpSpace: RP
) -> ParserResultType<RP> {
    if case let .bodyResult(e) = input, let target = rpSpace.bodyById(e)?.getTarget() {
        return .bodyResult(body: target)
    }
    return .nothing
}

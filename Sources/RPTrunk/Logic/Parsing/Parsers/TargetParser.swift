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
    if case let .entityResult(e) = input, let target = rpSpace.entityById(e)?.getTarget() {
        return .entityResult(entity: target)
    }
    return .nothing
}

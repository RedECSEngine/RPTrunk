//
//  StatusParser.swift
//
//
//  Created by Kyle Newsome on 2021-05-31.
//


func getStatus
<RP: RPSpace>
(_ status: String) -> (ParserResultType<RP>, RPConditionContext, RP) -> ParserResultType<RP> {
    {
        input, _, rpSpace in
        if case let .bodyResult(e) = input {
            let found = rpSpace.bodyById(e)?.hasStatus(RPStatusTag(status)) == true
            return .valueResult(.bool(found))
        }
        return .nothing
    }
}

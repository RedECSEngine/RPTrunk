//
//  StatusParser.swift
//  
//
//  Created by Kyle Newsome on 2021-05-31.
//


func getStatus
<RP: RPSpace>
(_ status: String) -> (ParserResultType<RP>, RP) -> ParserResultType<RP> {
    {
        input, rpSpace in
        if case let .bodyResult(e) = input {
            let found = rpSpace.bodyById(e)?.hasStatus(RPStatusCode(status)) == true
            return .valueResult(.bool(found))
        }
        return .nothing
    }
}

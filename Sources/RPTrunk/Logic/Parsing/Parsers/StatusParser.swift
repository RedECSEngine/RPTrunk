//
//  StatusParser.swift
//  
//
//  Created by Kyle Newsome on 2021-05-31.
//

import Foundation
import Parsing

func getStatus
<RP: RPSpace>
(_ status: String) -> (ParserResultType<RP>, RP) -> ParserResultType<RP> {
    {
        input, rpSpace in
        if case let .entityResult(e) = input {
            let found = rpSpace.entityById(e)?.hasStatus(status) == true
            return .valueResult(.bool(found))
        }
        return .nothing
    }
}

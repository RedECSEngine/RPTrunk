//
//  TargetParser.swift
//  
//
//  Created by Kyle Newsome on 2021-05-31.
//

import Foundation
import Parsing

func getTarget<RP: RPSpace>(
    _ input: ParserResultType<RP>,
    in rpSpace: RP
) -> ParserResultType<RP> {
    if case let .entityResult(e) = input, let target = rpSpace.entityById(e)?.getTarget() {
        return .entityResult(entity: target)
    }
    return .nothing
}

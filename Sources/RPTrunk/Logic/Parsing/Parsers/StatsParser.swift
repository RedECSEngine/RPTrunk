//
//  StatsParser.swift
//  
//
//  Created by Kyle Newsome on 2021-05-31.
//

import Foundation
import Parsing

func getStat<RP: RPSpace>(_ stat: String, usePercent: Bool) -> (ParserResultType<RP>, RP) -> ParserResultType<RP> {
    { input, rpSpace in
        if case let .entityResult(e) = input,
           let rpEntity = rpSpace.entityById(e) {
            let currentValue = rpEntity[stat]
            if usePercent {
                let percent: Double = floor(Double(currentValue) / Double(rpEntity.getTotalStats(in: rpSpace)[stat]) * 100)
                return .valueResult(.percent(percent))
            }
            return .valueResult(.rpValue(currentValue))
        }
        return .nothing
    }
}

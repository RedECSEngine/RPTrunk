//
//  StatsParser.swift
//  
//
//  Created by Kyle Newsome on 2021-05-31.
//


func getStat<RP: RPSpace>(_ stat: String, usePercent: Bool) -> (ParserResultType<RP>, RP) -> ParserResultType<RP> {
    { input, rpSpace in
        if case let .entityResult(e) = input,
           let rpEntity = rpSpace.entityById(e) {
            let currentValue = rpEntity[stat]
            if usePercent {
                let percent: Double = (Double(currentValue) / Double(RP.fullyResolvedStats(for: rpEntity)[stat]) * 100).rounded()
                return .valueResult(.percent(percent))
            }
            return .valueResult(.rpValue(currentValue))
        }
        return .nothing
    }
}

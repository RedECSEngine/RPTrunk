func tickTriggerCooldowns(
    _ cooldowns: inout [RPReferenceCode: RPTimeIncrement],
    by delta: RPTimeIncrement
) {
    for code in cooldowns.keys {
        let remaining = (cooldowns[code] ?? 0) - delta
        cooldowns[code] = remaining > 0 ? remaining : nil
    }
}

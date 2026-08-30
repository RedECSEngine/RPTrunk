import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct RPTrunkMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StatsStructMacro.self,
    ]
}

import RPTrunkMacros
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

final class StatsStructMacroTests: XCTestCase {
    let macros: [String: Macro.Type] = ["StatsStruct": StatsStructMacro.self]
    let macroSpecs: [String: MacroSpec] = [
        "StatsStruct": MacroSpec(type: StatsStructMacro.self, conformances: ["StatsType"]),
    ]

    func testExpansionSynthesizesAllMembers() {
        assertMacroExpansion(
            """
            @StatsStruct
            public struct Stats {
                public var hp: Int = 0
                public var damage: Int = 0
            }
            """,
            expandedSource: """
            public struct Stats {
                public var hp: Int = 0
                public var damage: Int = 0

                public init() {
                }

                public static let zero = Self()

                nonisolated(unsafe) public static let dynamicKeys: [String: WritableKeyPath<Self, Int>] = [
                    "hp": \\.hp,
                    "damage": \\.damage,
                ]

                nonisolated(unsafe) public static let numericAndComparableKeys: [WritableKeyPath<Self, Int>] = [
                    \\.hp,
                    \\.damage,
                ]

                public init(integerLiteral value: Int) {
                    hp = value
                    damage = value
                }

                public static func + (lhs: Self, rhs: Self) -> Self {
                    var result = lhs
                    result.hp += rhs.hp
                    result.damage += rhs.damage
                    return result
                }

                public static func - (lhs: Self, rhs: Self) -> Self {
                    var result = lhs
                    result.hp -= rhs.hp
                    result.damage -= rhs.damage
                    return result
                }

                public static func * (lhs: Self, rhs: Self) -> Self {
                    var result = lhs
                    result.hp *= rhs.hp
                    result.damage *= rhs.damage
                    return result
                }

                public static func < (lhs: Self, rhs: Self) -> Bool {
                    lhs.hp < rhs.hp
                        || lhs.damage < rhs.damage
                }
            }

            extension Stats: StatsType {
            }
            """,
            macroSpecs: macroSpecs
        )
    }

    func testExpansionSkipsComputedAndStaticProperties() {
        assertMacroExpansion(
            """
            @StatsStruct
            struct Stats {
                var hp: Int = 0
                static var shared = Stats()
                var doubledHp: Int { hp * 2 }
            }
            """,
            expandedSource: """
            struct Stats {
                var hp: Int = 0
                static var shared = Stats()
                var doubledHp: Int { hp * 2 }

                init() {
                }

                static let zero = Self()

                nonisolated(unsafe) static let dynamicKeys: [String: WritableKeyPath<Self, Int>] = [
                    "hp": \\.hp,
                ]

                nonisolated(unsafe) static let numericAndComparableKeys: [WritableKeyPath<Self, Int>] = [
                    \\.hp,
                ]

                init(integerLiteral value: Int) {
                    hp = value
                }

                static func + (lhs: Self, rhs: Self) -> Self {
                    var result = lhs
                    result.hp += rhs.hp
                    return result
                }

                static func - (lhs: Self, rhs: Self) -> Self {
                    var result = lhs
                    result.hp -= rhs.hp
                    return result
                }

                static func * (lhs: Self, rhs: Self) -> Self {
                    var result = lhs
                    result.hp *= rhs.hp
                    return result
                }

                static func < (lhs: Self, rhs: Self) -> Bool {
                    lhs.hp < rhs.hp
                }
            }

            extension Stats: StatsType {
            }
            """,
            macroSpecs: macroSpecs
        )
    }

    func testRejectsNonStruct() {
        assertMacroExpansion(
            """
            @StatsStruct
            enum Stats {
            }
            """,
            expandedSource: """
            enum Stats {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@StatsStruct can only be applied to a struct",
                    line: 1,
                    column: 1
                ),
            ],
            macros: macros
        )
    }

    func testRejectsNonIntStoredProperty() {
        assertMacroExpansion(
            """
            @StatsStruct
            struct Stats {
                var hp: Int = 0
                var name: String = ""
            }
            """,
            expandedSource: """
            struct Stats {
                var hp: Int = 0
                var name: String = ""
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@StatsStruct requires every stored property to be an Int, but 'name' is 'String'",
                    line: 4,
                    column: 15
                ),
            ],
            macros: macros
        )
    }

    func testRejectsImmutableStoredProperty() {
        assertMacroExpansion(
            """
            @StatsStruct
            struct Stats {
                let hp: Int = 0
            }
            """,
            expandedSource: """
            struct Stats {
                let hp: Int = 0
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@StatsStruct requires every stored property to be a 'var' so it can be written through a WritableKeyPath",
                    line: 3,
                    column: 5
                ),
            ],
            macros: macros
        )
    }

    func testRejectsMissingDefaultValue() {
        assertMacroExpansion(
            """
            @StatsStruct
            struct Stats {
                var hp: Int
            }
            """,
            expandedSource: """
            struct Stats {
                var hp: Int
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@StatsStruct requires every stored property to have a default value, e.g. 'var hp: Int = 0'",
                    line: 3,
                    column: 9
                ),
            ],
            macros: macros
        )
    }

    func testRejectsUnannotatedNonLiteralProperty() {
        assertMacroExpansion(
            """
            @StatsStruct
            struct Stats {
                var hp = makeValue()
            }
            """,
            expandedSource: """
            struct Stats {
                var hp = makeValue()
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@StatsStruct cannot verify that 'hp' is an Int; annotate it as 'var hp: Int = 0'",
                    line: 3,
                    column: 9
                ),
            ],
            macros: macros
        )
    }

    func testRejectsEmptyStruct() {
        assertMacroExpansion(
            """
            @StatsStruct
            struct Stats {
            }
            """,
            expandedSource: """
            struct Stats {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@StatsStruct requires at least one stored Int property",
                    line: 2,
                    column: 8
                ),
            ],
            macros: macros
        )
    }
}

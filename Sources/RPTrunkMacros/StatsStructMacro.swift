import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct StatsStructMacro {}

struct StatsStructDiagnostic: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity = .error

    init(id: String, _ message: String) {
        self.message = message
        diagnosticID = MessageID(domain: "RPTrunkMacros", id: id)
    }
}

extension StatsStructMacro {
    static func error(_ node: some SyntaxProtocol, id: String, _ message: String) -> Diagnostic {
        Diagnostic(node: node, message: StatsStructDiagnostic(id: id, message))
    }

    static func storedPropertyNames(of structDecl: StructDeclSyntax) throws -> [String] {
        var names: [String] = []
        var diagnostics: [Diagnostic] = []

        for member in structDecl.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else {
                continue
            }
            if variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class) }) {
                continue
            }
            if isComputed(variable) {
                continue
            }
            if variable.bindingSpecifier.tokenKind == .keyword(.let) {
                diagnostics.append(error(
                    variable,
                    id: "immutableProperty",
                    "@StatsStruct requires every stored property to be a 'var' so it can be written through a WritableKeyPath"
                ))
                continue
            }
            for binding in variable.bindings {
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
                    diagnostics.append(error(
                        binding,
                        id: "unsupportedPattern",
                        "@StatsStruct only supports simple 'var name: Int = 0' stored properties"
                    ))
                    continue
                }
                let name = identifier.identifier.text
                if let annotation = binding.typeAnnotation {
                    guard isIntType(annotation.type) else {
                        diagnostics.append(error(
                            annotation.type,
                            id: "nonIntProperty",
                            "@StatsStruct requires every stored property to be an Int, but '\(name)' is '\(annotation.type.trimmedDescription)'"
                        ))
                        continue
                    }
                } else if binding.initializer.map({ isIntLiteral($0.value) }) != true {
                    diagnostics.append(error(
                        binding,
                        id: "unknownType",
                        "@StatsStruct cannot verify that '\(name)' is an Int; annotate it as 'var \(name): Int = 0'"
                    ))
                    continue
                }
                guard binding.initializer != nil else {
                    diagnostics.append(error(
                        binding,
                        id: "missingDefault",
                        "@StatsStruct requires every stored property to have a default value, e.g. 'var \(name): Int = 0'"
                    ))
                    continue
                }
                names.append(name)
            }
        }

        if names.isEmpty, diagnostics.isEmpty {
            diagnostics.append(error(
                structDecl.name,
                id: "noStoredProperties",
                "@StatsStruct requires at least one stored Int property"
            ))
        }
        guard diagnostics.isEmpty else {
            throw DiagnosticsError(diagnostics: diagnostics)
        }
        return names
    }

    static func isComputed(_ variable: VariableDeclSyntax) -> Bool {
        variable.bindings.contains { binding in
            guard let accessorBlock = binding.accessorBlock else {
                return false
            }
            switch accessorBlock.accessors {
            case .getter:
                return true
            case let .accessors(accessors):
                return accessors.contains { accessor in
                    accessor.accessorSpecifier.tokenKind != .keyword(.willSet)
                        && accessor.accessorSpecifier.tokenKind != .keyword(.didSet)
                }
            }
        }
    }

    static func isIntType(_ type: TypeSyntax) -> Bool {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text == "Int"
        }
        if let member = type.as(MemberTypeSyntax.self),
           let base = member.baseType.as(IdentifierTypeSyntax.self)
        {
            return base.name.text == "Swift" && member.name.text == "Int"
        }
        return false
    }

    static func isIntLiteral(_ expression: ExprSyntax) -> Bool {
        if expression.is(IntegerLiteralExprSyntax.self) {
            return true
        }
        if let prefixed = expression.as(PrefixOperatorExprSyntax.self) {
            return prefixed.expression.is(IntegerLiteralExprSyntax.self)
        }
        return false
    }

    static func accessPrefix(of structDecl: StructDeclSyntax) -> String {
        for modifier in structDecl.modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public), .keyword(.open):
                return "public "
            case .keyword(.package):
                return "package "
            default:
                continue
            }
        }
        return ""
    }
}

extension StatsStructMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw DiagnosticsError(diagnostics: [
                error(node, id: "notAStruct", "@StatsStruct can only be applied to a struct"),
            ])
        }

        let names = try storedPropertyNames(of: structDecl)
        let acl = accessPrefix(of: structDecl)

        let dynamicKeyEntries = names
            .map { "\"\($0)\": \\.\($0)," }
            .joined(separator: "\n    ")
        let literalAssignments = names
            .map { "\($0) = value" }
            .joined(separator: "\n    ")
        let absoluteAssignments = names
            .map { "result.\($0) = abs(result.\($0))" }
            .joined(separator: "\n    ")
        func combining(_ op: String) -> String {
            names
                .map { "result.\($0) \(op)= rhs.\($0)" }
                .joined(separator: "\n    ")
        }
        let lessThan = names
            .map { "lhs.\($0) < rhs.\($0)" }
            .joined(separator: "\n        || ")
        let definitionProperties = names
            .map { "\(acl)var \($0): String?" }
            .joined(separator: "\n    ")
        let definitionCells = names
            .map { "if let \($0) { cells[\"\($0)\"] = \($0) }" }
            .joined(separator: "\n        ")

        return [
            "\(raw: acl)init() {}",
            "\(raw: acl)static let zero = Self()",
            """
            nonisolated(unsafe) \(raw: acl)static let dynamicKeys: [String: WritableKeyPath<Self, Int>] = [
                \(raw: dynamicKeyEntries)
            ]
            """,
            """
            \(raw: acl)init(integerLiteral value: Int) {
                \(raw: literalAssignments)
            }
            """,
            """
            \(raw: acl)init?<T: BinaryInteger>(exactly source: T) {
                guard let value = Int(exactly: source) else {
                    return nil
                }
                self.init(integerLiteral: value)
            }
            """,
            """
            \(raw: acl)var magnitude: Self {
                var result = self
                \(raw: absoluteAssignments)
                return result
            }
            """,
            """
            \(raw: acl)static func + (lhs: Self, rhs: Self) -> Self {
                var result = lhs
                \(raw: combining("+"))
                return result
            }
            """,
            """
            \(raw: acl)static func - (lhs: Self, rhs: Self) -> Self {
                var result = lhs
                \(raw: combining("-"))
                return result
            }
            """,
            """
            \(raw: acl)static func * (lhs: Self, rhs: Self) -> Self {
                var result = lhs
                \(raw: combining("*"))
                return result
            }
            """,
            """
            \(raw: acl)static func *= (lhs: inout Self, rhs: Self) {
                lhs = lhs * rhs
            }
            """,
            """
            \(raw: acl)static func < (lhs: Self, rhs: Self) -> Bool {
                \(raw: lessThan)
            }
            """,
            """
            \(raw: acl)struct ItemDefinition<Metadata: Codable & Equatable & Sendable>: RPItemDefining {
                \(raw: acl)var code: String
                \(raw: acl)var displayName: String?
                \(raw: acl)var tags: String?
                \(raw: acl)var equipmentSlotCode: String?
                \(raw: acl)var maxNumberOfOptionalStats: Int?
                \(raw: acl)var metadata: Metadata?

                \(raw: definitionProperties)

                \(raw: acl)var statCells: [String: String] {
                    var cells: [String: String] = [:]
                    \(raw: definitionCells)
                    return cells
                }
            }
            """,
        ]
    }
}

extension StatsStructMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(StructDeclSyntax.self), !protocols.isEmpty else {
            return []
        }
        return [try ExtensionDeclSyntax("extension \(type.trimmed): StatsType {}")]
    }
}

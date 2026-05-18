//
//  GroundedExtractableMacro.swift
//  GroundedExtraction
//
//  Created by Fabian Rottensteiner on 18.05.26.
//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct GroundedExtractableMacro: MemberMacro, ExtensionMacro {
    // MARK: - MemberMacro: synthesizes Plan struct + helper methods

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(Diagnostic(
                node: node,
                message: GroundingDiagnostic.notAStruct
            ))
            return []
        }

        // Extract `let foo: String?` style properties
        let properties = extractProperties(from: structDecl)

        guard !properties.isEmpty else { return [] }

        // Build the Plan struct
        let planMembers = properties.map { prop in
            let capitalized = prop.name.prefix(1).uppercased() + prop.name.dropFirst()
            return """
            @Guide(description: "True ONLY if '\(prop.name)' is literally present in the input text.")
            let has\(capitalized): Bool
            """
        }.joined(separator: "\n    ")

        let planStruct: DeclSyntax = """
        @Generable(description: "Field presence analysis.")
        struct Plan: Sendable {
            \(raw: planMembers)
        }
        """

        // Build allowedFields(from:)
        let allowedFieldsBody = properties.map { prop in
            let capitalized = prop.name.prefix(1).uppercased() + prop.name.dropFirst()
            return "if plan.has\(capitalized) { result.insert(\"\(prop.name)\") }"
        }.joined(separator: "\n        ")

        let allowedFieldsFunc: DeclSyntax = """
        static func allowedFields(from plan: Plan) -> Set<String> {
            var result: Set<String> = []
            \(raw: allowedFieldsBody)
            return result
        }
        """

        // Build applying(plan:)
        let applyingArgs = properties.map { prop in
            let capitalized = prop.name.prefix(1).uppercased() + prop.name.dropFirst()
            return "\(prop.name): plan.has\(capitalized) ? \(prop.name) : nil"
        }.joined(separator: ",\n            ")

        let typeName = structDecl.name.text
        let applyingFunc: DeclSyntax = """
        func applying(plan: Plan) -> \(raw: typeName) {
            \(raw: typeName)(
                \(raw: applyingArgs)
            )
        }
        """

        // Build sanitized(against:) – defaults all String? fields to .textToken
        let sanitizerEntries = properties
            .filter { $0.isOptionalString }
            .map { "(\\.\($0.name), .textToken)" }
            .joined(separator: ",\n            ")

        let sanitizedFunc: DeclSyntax = """
        func sanitized(against rawInput: String) -> \(raw: typeName) {
            GroundingSanitizer.sanitize(self, against: rawInput, keyPaths: [
                \(raw: sanitizerEntries)
            ])
        }
        """

        // Defaults for optional protocol requirements
        let defaults: DeclSyntax = """
        static var groundingInstructions: String { "" }
        static var groundingExamples: [GroundingExample] { [] }
        """

        return [planStruct, allowedFieldsFunc, applyingFunc, sanitizedFunc, defaults]
    }

    // MARK: - ExtensionMacro: adds the protocol conformance

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let ext: DeclSyntax = """
        extension \(type.trimmed): GroundedExtractable {}
        """
        return [ext.cast(ExtensionDeclSyntax.self)]
    }
}

// MARK: - Property extraction helper

private struct PropertyInfo {
    let name: String
    let isOptionalString: Bool
}

private func extractProperties(from structDecl: StructDeclSyntax) -> [PropertyInfo] {
    structDecl.memberBlock.members.compactMap { member -> PropertyInfo? in
        guard
            let varDecl = member.decl.as(VariableDeclSyntax.self),
            let binding = varDecl.bindings.first,
            let identPattern = binding.pattern.as(IdentifierPatternSyntax.self),
            let typeAnnotation = binding.typeAnnotation
        else { return nil }

        let name = identPattern.identifier.text
        let typeDescription = typeAnnotation.type.trimmedDescription

        // Detect String? (handles both `String?` and `Optional<String>`)
        let isOptionalString =
        typeDescription == "String?" ||
        typeDescription == "Optional<String>"

        return PropertyInfo(name: name, isOptionalString: isOptionalString)
    }
}

// MARK: - Diagnostics

private enum GroundingDiagnostic: String, DiagnosticMessage {
    case notAStruct

    var severity: DiagnosticSeverity { .error }
    var message: String {
        switch self {
        case .notAStruct:
            return "@GroundedExtractable can only be applied to structs."
        }
    }
    var diagnosticID: MessageID {
        MessageID(domain: "GroundedExtractionMacros", id: rawValue)
    }
}

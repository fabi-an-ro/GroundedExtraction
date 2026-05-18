import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct GroundedExtractionPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        GroundedExtractableMacro.self,
    ]
}

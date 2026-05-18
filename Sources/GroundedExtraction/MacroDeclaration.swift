// The Swift Programming Language
// https://docs.swift.org/swift-book

@attached(member, names: arbitrary)
@attached(extension, conformances: GroundedExtractable, names: arbitrary)
public macro GroundedExtractable() = #externalMacro(
    module: "GroundedExtractionMacros",
    type: "GroundedExtractableMacro"
)

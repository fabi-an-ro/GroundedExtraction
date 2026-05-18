// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "GroundedExtraction",
    platforms: [
        .iOS(.v26),
    ],
    products: [
        .library(
            name: "GroundedExtraction",
            targets: ["GroundedExtraction"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "600.0.0"
        ),
    ],
    targets: [
        .macro(
            name: "GroundedExtractionMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "GroundedExtraction",
            dependencies: ["GroundedExtractionMacros"]
        ),
    ]
)

//
//  GroundedExtractable.swift
//  GroundedExtraction
//
//  Created by Fabian Rottensteiner on 18.05.26.
//

import FoundationModels

/// A type that can be extracted from raw text via a two-pass LLM pipeline
/// with deterministic post-processing.
public protocol GroundedExtractable: Generable, Sendable {

    /// A companion plan type holding one Bool per extractable field.
    associatedtype Plan: Generable & Sendable

    /// Build a list of allowed field names from the plan.
    static func allowedFields(from plan: Plan) -> Set<String>

    /// Apply the plan: force-nil every field the plan said wasn't present.
    func applying(plan: Plan) -> Self

    /// Sanitize: drop string fields whose content doesn't appear in the input.
    func sanitized(against rawInput: String) -> Self

    /// Optional system instructions tailored to this type.
    static var groundingInstructions: String { get }

    /// Optional few-shot examples for the extraction pass.
    static var groundingExamples: [GroundingExample] { get }
}

/// A simple input/output example used to anchor the LLM during extraction.
public struct GroundingExample: Sendable {
    public let input: String
    public let expectedJSON: String

    public init(input: String, expectedJSON: String) {
        self.input = input
        self.expectedJSON = expectedJSON
    }
}

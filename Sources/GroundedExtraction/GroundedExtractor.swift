//
//  GroundedExtractor.swift
//  GroundedExtraction
//
//  Created by Fabian Rottensteiner on 18.05.26.
//

import FoundationModels

/// Two-pass grounded extraction pipeline for any GroundedExtractable type.
public actor GroundedExtractor<T: GroundedExtractable> {

    private let session: LanguageModelSession

    public init(session: LanguageModelSession) {
        self.session = session
    }

    public func extract(from rawInput: String) async throws -> T {
        // Pass 1: presence plan
        let plan = try await session.respond(
            to: Self.planPrompt(rawInput: rawInput),
            generating: T.Plan.self,
            options: GenerationOptions(temperature: 0.0)
        ).content

        // Pass 2: targeted extraction
        let allowed = T.allowedFields(from: plan)
        let raw = try await session.respond(
            to: Self.extractionPrompt(
                rawInput: rawInput,
                allowedFields: allowed,
                examples: T.groundingExamples
            ),
            generating: T.self,
            options: GenerationOptions(temperature: 0.0)
        ).content

        // Pass 3: deterministic backstop
        return raw
            .applying(plan: plan)
            .sanitized(against: rawInput)
    }

    private static func planPrompt(rawInput: String) -> String {
        """
        Analyze STRICTLY which fields are explicitly present in the text.
        When in doubt, answer false. Do not infer or derive.
        
        Text:
        \"\"\"
        \(rawInput)
        \"\"\"
        """
    }

    private static func extractionPrompt(
        rawInput: String,
        allowedFields: Set<String>,
        examples: [GroundingExample]
    ) -> String {
        let allowed = allowedFields.isEmpty
        ? "NONE – return all fields as nil."
        : allowedFields.sorted().joined(separator: ", ")

        var prompt = """
        Extract data from the text below.
        
        ONLY fill these fields: \(allowed)
        Set ALL other fields to nil.
        
        Each filled field must contain content that appears LITERALLY in the text.
        Do NOT translate, normalize, complete, or paraphrase.
        """

        if !examples.isEmpty {
            prompt += "\n\nExamples:\n"
            for example in examples {
                prompt += "\nInput: \(example.input)\nOutput: \(example.expectedJSON)\n"
            }
        }

        prompt += "\n\nText:\n\"\"\"\n\(rawInput)\n\"\"\""
        return prompt
    }
}

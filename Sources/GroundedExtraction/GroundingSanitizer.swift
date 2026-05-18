//
//  GroundingSanitizer.swift
//  GroundedExtraction
//
//  Created by Fabian Rottensteiner on 18.05.26.
//

import Foundation

/// How a field should be checked against the raw input text.
public enum SanitizationStrategy: Sendable {
    /// Verify each significant word token appears in the input
    /// (diacritic-insensitive, lowercased).
    case textToken

    /// Verify the digit sequence inside the value appears in the input.
    case exactDigits

    /// Skip sanitization for this field.
    case skip

    /// Custom predicate: (fieldValue, rawInput) -> isValid.
    case custom(@Sendable (String, String) -> Bool)
}

/// Deterministic post-processing for grounded extraction.
/// Drops fields whose values don't actually appear in the raw input.
public enum GroundingSanitizer {

    public static func sanitize<T>(
        _ value: T,
        against rawInput: String,
        keyPaths: [(WritableKeyPath<T, String?>, SanitizationStrategy)]
    ) -> T {
        var copy = value
        let normalizedInput = normalize(rawInput)

        for (keyPath, strategy) in keyPaths {
            guard let fieldValue = copy[keyPath: keyPath] else { continue }

            if !passesStrategy(
                value: fieldValue,
                strategy: strategy,
                normalizedInput: normalizedInput,
                rawInput: rawInput
            ) {
                copy[keyPath: keyPath] = nil
            }
        }
        return copy
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "de_AT"))
    }

    private static func passesStrategy(
        value: String,
        strategy: SanitizationStrategy,
        normalizedInput: String,
        rawInput: String
    ) -> Bool {
        switch strategy {
        case .skip:
            return true

        case .exactDigits:
            let digits = value.filter(\.isNumber)
            return digits.isEmpty || normalizedInput.contains(digits)

        case .textToken:
            let tokens = normalize(value)
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
                .filter { $0.count >= 3 }
            guard !tokens.isEmpty else { return true }
            return tokens.allSatisfy { normalizedInput.contains($0) }

        case .custom(let predicate):
            return predicate(value, rawInput)
        }
    }
}

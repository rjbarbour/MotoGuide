import Foundation

enum FactPhraseBuilder {
    static let maxFactLength = 120

    static func utterance(basePhrase: String, fact: String?) -> String {
        guard let sanitized = sanitize(fact) else {
            return basePhrase
        }
        return "\(basePhrase). \(sanitized)"
    }

    static func sanitize(_ fact: String?) -> String? {
        guard var text = fact?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }

        if (text.hasPrefix("\"") && text.hasSuffix("\"")) || (text.hasPrefix("'") && text.hasSuffix("'")) {
            text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        text = text.replacingOccurrences(of: "\n", with: " ")

        if text.contains("?") || text.lowercased().contains("you should") {
            return nil
        }

        if text.count > maxFactLength {
            text = String(text.prefix(maxFactLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return text.isEmpty ? nil : text
    }
}

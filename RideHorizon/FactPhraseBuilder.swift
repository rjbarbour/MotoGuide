import Foundation

enum FactPhraseBuilder {
    static let defaultFactMode: FactMode = .shortFacts
    static let maxFactLength = FactMode.shortFacts.maxFactLength

    static func utterance(basePhrase: String, fact: String?, mode: FactMode = defaultFactMode) -> String {
        guard let sanitized = sanitize(fact, mode: mode) else {
            return basePhrase
        }
        return "\(basePhrase). \(sanitized)"
    }

    static func sanitize(_ fact: String?, mode: FactMode = defaultFactMode) -> String? {
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

        if text.count > mode.maxFactLength {
            text = String(text.prefix(mode.maxFactLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return text.isEmpty ? nil : text
    }
}

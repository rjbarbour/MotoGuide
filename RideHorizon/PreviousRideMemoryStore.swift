import Foundation

struct PreviousRideSummary: Codable, Equatable {
    let endedAt: Date
    let content: String
}

final class PreviousRideMemoryStore {
    static let shared = PreviousRideMemoryStore()
    static let maximumSummaries = 3
    static let maximumSummaryCharacters = 720
    static let maximumFactCharacters = 240

    private static let defaultStorageKey = "PreviousRideSummaries"
    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = PreviousRideMemoryStore.defaultStorageKey
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    var summaries: [PreviousRideSummary] {
        guard let stored = defaults.object(forKey: storageKey) else { return [] }
        guard let data = stored as? Data,
              let decoded = try? JSONDecoder().decode([PreviousRideSummary].self, from: data) else {
            defaults.removeObject(forKey: storageKey)
            return []
        }

        let recovered = decoded.compactMap { summary -> PreviousRideSummary? in
            let content = Self.bounded(
                Self.normalized(summary.content),
                maximumCharacters: Self.maximumSummaryCharacters
            )
            guard !content.isEmpty else { return nil }
            return PreviousRideSummary(endedAt: summary.endedAt, content: content)
        }.suffix(Self.maximumSummaries)
        let summaries = Array(recovered)
        if summaries != decoded {
            persist(summaries)
        }
        return summaries
    }

    func completeRide(deliveredFacts: [String], endedAt: Date) {
        let content = Self.compact(deliveredFacts)
        guard !content.isEmpty else { return }

        var updated = summaries
        updated.append(PreviousRideSummary(endedAt: endedAt, content: content))
        updated = Array(updated.suffix(Self.maximumSummaries))
        persist(updated)
    }

    func clear() {
        defaults.removeObject(forKey: storageKey)
    }

    private func persist(_ summaries: [PreviousRideSummary]) {
        guard let data = try? JSONEncoder().encode(summaries) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func compact(_ deliveredFacts: [String]) -> String {
        var seen = Set<String>()
        var content = ""

        for deliveredFact in deliveredFacts {
            let normalized = normalized(deliveredFact)
            guard !normalized.isEmpty,
                  seen.insert(normalized.lowercased()).inserted else { continue }

            let excerpt = bounded(normalized, maximumCharacters: maximumFactCharacters)
            let separator = content.isEmpty ? "" : " "
            let remaining = maximumSummaryCharacters - content.count - separator.count
            guard remaining > 0 else { break }
            content += separator + bounded(excerpt, maximumCharacters: remaining)
        }
        return content
    }

    private static func bounded(_ content: String, maximumCharacters: Int) -> String {
        guard content.count > maximumCharacters else { return content }
        guard maximumCharacters > 1 else { return String(content.prefix(maximumCharacters)) }
        return String(content.prefix(maximumCharacters - 1))
            .trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func normalized(_ content: String) -> String {
        content.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

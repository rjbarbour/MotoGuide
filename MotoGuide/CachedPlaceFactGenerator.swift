import Foundation

struct CachedPlaceFactGenerator: PlaceFactGenerating {
    private let generator: PlaceFactGenerating
    private let cache: PlaceFactCache

    init(generator: PlaceFactGenerating, cache: PlaceFactCache = .shared) {
        self.generator = generator
        self.cache = cache
    }

    func fact(for request: PlaceFactRequest) async throws -> String {
        if let cached = cache.fact(forKey: request.cacheKey) {
            return cached
        }

        let fact = try await generator.fact(for: request)
        if let sanitized = FactPhraseBuilder.sanitize(fact) {
            cache.store(sanitized, forKey: request.cacheKey)
            return sanitized
        }
        throw PlaceFactError.invalidResponse
    }
}

enum PlaceFactFetcher {
    static let fetchTimeoutSeconds: TimeInterval = 3

    static func fact(
        for request: PlaceFactRequest,
        using generator: PlaceFactGenerating,
        timeout: TimeInterval = fetchTimeoutSeconds
    ) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask {
                do {
                    return try await generator.fact(for: request)
                } catch {
                    return nil
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }

            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? nil
        }
    }
}

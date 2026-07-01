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
            ProxyDiagnostics.log("Facts", "Cache hit for \(request.cacheKey)")
            return cached
        }

        ProxyDiagnostics.log("Facts", "Cache miss for \(request.cacheKey)")
        let fact = try await generator.fact(for: request)
        if let sanitized = FactPhraseBuilder.sanitize(fact) {
            cache.store(sanitized, forKey: request.cacheKey)
            ProxyDiagnostics.log("Facts", "Stored fact in cache for \(request.cacheKey)")
            return sanitized
        }
        ProxyDiagnostics.log("Facts", "Generated fact failed local sanitization for \(request.cacheKey)")
        throw PlaceFactError.invalidResponse
    }
}

enum PlaceFactFetcher {
    static let fetchTimeoutSeconds = FactProxyContract.iosTimeoutSeconds

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
                    ProxyDiagnostics.log("Facts", "Fact fetch failed for \(request.cacheKey): \(error.localizedDescription)")
                    return nil
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                ProxyDiagnostics.log("Facts", "Fact fetch timed out after \(timeout)s for \(request.cacheKey)")
                return nil
            }

            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? nil
        }
    }
}

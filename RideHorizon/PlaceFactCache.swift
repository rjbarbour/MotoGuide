import Foundation

final class PlaceFactCache {
    static let shared = PlaceFactCache()

    private let defaultsKey = "ridehorizon.placeFactCache"
    private let timestampsKey = "ridehorizon.placeFactCache.timestamps"
    private let maximumAge: TimeInterval
    private let now: () -> Date
    private let defaults: UserDefaults
    private let persists: Bool
    private var memory: [String: String] = [:]
    private var storedAt: [String: Date] = [:]
    private let lock = NSLock()

    init(
        defaults: UserDefaults = .standard,
        loadPersisted: Bool = true,
        maximumAge: TimeInterval = 30 * 24 * 60 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.persists = loadPersisted
        self.maximumAge = maximumAge
        self.now = now
        if loadPersisted {
            let loadedFacts = defaults.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
            let loadedTimestamps = defaults.dictionary(forKey: timestampsKey) as? [String: Date] ?? [:]
            let cutoff = now().addingTimeInterval(-maximumAge)
            memory = loadedFacts.filter { key, _ in
                guard let timestamp = loadedTimestamps[key] else { return false }
                return timestamp >= cutoff
            }
            storedAt = loadedTimestamps.filter { memory[$0.key] != nil }
            persist(facts: memory, timestamps: storedAt)
        }
    }

    func fact(forKey key: String) -> String? {
        lock.lock()
        guard let fact = memory[key],
              let timestamp = storedAt[key],
              now().timeIntervalSince(timestamp) <= maximumAge else {
            memory.removeValue(forKey: key)
            storedAt.removeValue(forKey: key)
            let facts = memory
            let timestamps = storedAt
            lock.unlock()
            persist(facts: facts, timestamps: timestamps)
            return nil
        }
        lock.unlock()
        return fact
    }

    func store(_ fact: String, forKey key: String) {
        lock.lock()
        memory[key] = fact
        storedAt[key] = now()
        let facts = memory
        let timestamps = storedAt
        lock.unlock()
        persist(facts: facts, timestamps: timestamps)
    }

    func clear() {
        lock.lock()
        memory.removeAll()
        storedAt.removeAll()
        lock.unlock()
        guard persists else { return }
        defaults.removeObject(forKey: defaultsKey)
        defaults.removeObject(forKey: timestampsKey)
    }

    private func persist(facts: [String: String], timestamps: [String: Date]) {
        guard persists else { return }
        defaults.set(facts, forKey: defaultsKey)
        defaults.set(timestamps, forKey: timestampsKey)
    }
}

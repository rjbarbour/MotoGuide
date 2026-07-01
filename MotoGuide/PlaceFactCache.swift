import Foundation

final class PlaceFactCache {
    static let shared = PlaceFactCache()

    private let defaultsKey = "motoguide.placeFactCache"
    private var memory: [String: String] = [:]
    private let lock = NSLock()

    init(loadPersisted: Bool = true) {
        if loadPersisted {
            memory = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
        }
    }

    func fact(forKey key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return memory[key]
    }

    func store(_ fact: String, forKey key: String) {
        lock.lock()
        memory[key] = fact
        lock.unlock()
        UserDefaults.standard.set(memory, forKey: defaultsKey)
    }
}

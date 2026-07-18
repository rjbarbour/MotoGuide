import Foundation

/// Central store for first-run / onboarding flags persisted in UserDefaults.
final class FirstRunState: ObservableObject {
    enum Key: String, CaseIterable {
        case hasSeenPermissionExplanation
        case hasCompletedOnboarding
    }

    static let storagePrefix = "ai.digitalmercenaries.ridehorizon.firstRun."

    @Published private(set) var hasSeenPermissionExplanation: Bool
    @Published private(set) var hasCompletedOnboarding: Bool

    var needsOnboarding: Bool {
        !hasCompletedOnboarding
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasSeenPermissionExplanation = defaults.bool(forKey: Self.storageKey(.hasSeenPermissionExplanation))
        hasCompletedOnboarding = defaults.bool(forKey: Self.storageKey(.hasCompletedOnboarding))
    }

    func markPermissionExplanationSeen() {
        guard !hasSeenPermissionExplanation else { return }
        hasSeenPermissionExplanation = true
        defaults.set(true, forKey: Self.storageKey(.hasSeenPermissionExplanation))
    }

    func completeOnboarding() {
        guard !hasCompletedOnboarding else { return }
        hasCompletedOnboarding = true
        defaults.set(true, forKey: Self.storageKey(.hasCompletedOnboarding))
    }

    /// Clears all first-run flags so the next launch behaves like a fresh install.
    func reset() {
        for key in Key.allCases {
            defaults.removeObject(forKey: Self.storageKey(key))
        }
        hasSeenPermissionExplanation = false
        hasCompletedOnboarding = false
    }

    private static func storageKey(_ key: Key) -> String {
        storagePrefix + key.rawValue
    }
}

/// Stores the rider's explicit choice about sharing data with third-party AI providers.
final class AISharingConsentStore: ObservableObject {
    enum Decision: String, Equatable {
        case notDetermined
        case granted
        case declined
    }

    static let storageKey = "ai.digitalmercenaries.ridehorizon.privacy.aiSharingDecision"

    @Published private(set) var decision: Decision

    var isGranted: Bool {
        decision == .granted
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        decision = defaults.string(forKey: Self.storageKey)
            .flatMap(Decision.init(rawValue:)) ?? .notDetermined
    }

    func grant() {
        set(.granted)
    }

    func decline() {
        set(.declined)
    }

    func reset() {
        defaults.removeObject(forKey: Self.storageKey)
        decision = .notDetermined
    }

    static func isGranted(defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: storageKey) == Decision.granted.rawValue
    }

    private func set(_ newDecision: Decision) {
        decision = newDecision
        defaults.set(newDecision.rawValue, forKey: Self.storageKey)
    }
}

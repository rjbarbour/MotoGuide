import Foundation

struct RideSettings: Equatable {
    var boundarySpeechCooldownSeconds: Int
    var shortInactivityTimeout: Bool
    var testMode: Bool
    var interruptsMusic: Bool
    var premiumVoiceAppleFallbackEnabled: Bool
    var preferredVoiceIdentifier: String
    var speechProvider: SpeechProvider
    var lastNonQuietContentMode: ContentMode
    var homeCountry: String
    var homeRegion: String
    var familiarRegions: String
    var customFactInstructions: String
    var factInterestCategories: [FactInterestCategory]
}

enum RideSettingField {
    case boundarySpeechCooldownSeconds
    case shortInactivityTimeout
    case testMode
    case interruptsMusic
    case premiumVoiceAppleFallbackEnabled
    case preferredVoiceIdentifier
    case speechProvider
    case lastNonQuietContentMode
    case homeCountry
    case homeRegion
    case familiarRegions
    case customFactInstructions
    case factInterestCategories
}

protocol RideSettingsStore {
    func load() -> RideSettings
    func save(_ settings: RideSettings, changed field: RideSettingField)
}

struct UserDefaultsRideSettingsStore: RideSettingsStore {
    private enum Key {
        static let preferredVoiceIdentifier = "RideHorizonPreferredVoiceIdentifier"
        static let speechProvider = "RideHorizonSpeechProvider"
        static let speechProviderMigration = "RideHorizonSpeechProviderPremiumNoAppleFallbackMigration20260703"
        static let lastNonQuietContentMode = "RideHorizonLastNonQuietContentMode"
        static let premiumVoiceAppleFallbackEnabled = "RideHorizonPremiumVoiceAppleFallbackEnabled"
        static let interruptsMusic = "RideHorizonInterruptsMusic"
        static let homeCountry = "RideHorizonHomeCountry"
        static let homeRegion = "RideHorizonHomeRegion"
        static let familiarRegions = "RideHorizonFamiliarRegions"
        static let customFactInstructions = "RideHorizonCustomFactInstructions"
        static let factInterestCategories = "RideHorizonFactInterestCategories"
        static let boundarySpeechCooldownSeconds = "RideHorizonBoundarySpeechCooldownSeconds"
        static let testMode = "RideHorizonTestMode"
        static let audioInteropDebugTestModeChoice = "RideHorizonAudioInteropDebugTestModeChoice"
        static let shortInactivityTimeout = "RideHorizonShortInactivityTimeout"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> RideSettings {
        let speechProvider = loadSpeechProvider()
        let testMode: Bool
#if DEBUG
        testMode = defaults.bool(forKey: Key.audioInteropDebugTestModeChoice)
            ? defaults.bool(forKey: Key.testMode)
            : true
#else
        testMode = defaults.bool(forKey: Key.testMode)
#endif

        return RideSettings(
            boundarySpeechCooldownSeconds: defaults.object(forKey: Key.boundarySpeechCooldownSeconds) as? Int ?? 10,
            shortInactivityTimeout: defaults.bool(forKey: Key.shortInactivityTimeout),
            testMode: testMode,
            interruptsMusic: defaults.object(forKey: Key.interruptsMusic) == nil
                ? true
                : defaults.bool(forKey: Key.interruptsMusic),
            premiumVoiceAppleFallbackEnabled: defaults.object(forKey: Key.premiumVoiceAppleFallbackEnabled) == nil
                ? true
                : defaults.bool(forKey: Key.premiumVoiceAppleFallbackEnabled),
            preferredVoiceIdentifier: defaults.string(forKey: Key.preferredVoiceIdentifier) ?? "",
            speechProvider: speechProvider,
            lastNonQuietContentMode: defaults.string(forKey: Key.lastNonQuietContentMode)
                .flatMap(ContentMode.init(rawValue:)) ?? .shortFacts,
            homeCountry: defaults.string(forKey: Key.homeCountry) ?? "",
            homeRegion: defaults.string(forKey: Key.homeRegion) ?? "",
            familiarRegions: defaults.string(forKey: Key.familiarRegions) ?? "",
            customFactInstructions: defaults.string(forKey: Key.customFactInstructions) ?? "",
            factInterestCategories: loadFactInterestCategories()
        )
    }

    func save(_ settings: RideSettings, changed field: RideSettingField) {
        switch field {
        case .boundarySpeechCooldownSeconds:
            defaults.set(settings.boundarySpeechCooldownSeconds, forKey: Key.boundarySpeechCooldownSeconds)
        case .shortInactivityTimeout:
#if DEBUG
            defaults.set(settings.shortInactivityTimeout, forKey: Key.shortInactivityTimeout)
#else
            break
#endif
        case .testMode:
            defaults.set(settings.testMode, forKey: Key.testMode)
#if DEBUG
            defaults.set(true, forKey: Key.audioInteropDebugTestModeChoice)
#endif
        case .interruptsMusic:
            defaults.set(settings.interruptsMusic, forKey: Key.interruptsMusic)
        case .premiumVoiceAppleFallbackEnabled:
            defaults.set(settings.premiumVoiceAppleFallbackEnabled, forKey: Key.premiumVoiceAppleFallbackEnabled)
        case .preferredVoiceIdentifier:
            defaults.set(settings.preferredVoiceIdentifier, forKey: Key.preferredVoiceIdentifier)
        case .speechProvider:
            defaults.set(settings.speechProvider.rawValue, forKey: Key.speechProvider)
            defaults.set(true, forKey: Key.speechProviderMigration)
        case .lastNonQuietContentMode:
            defaults.set(settings.lastNonQuietContentMode.rawValue, forKey: Key.lastNonQuietContentMode)
        case .homeCountry:
            defaults.set(settings.homeCountry, forKey: Key.homeCountry)
        case .homeRegion:
            defaults.set(settings.homeRegion, forKey: Key.homeRegion)
        case .familiarRegions:
            defaults.set(settings.familiarRegions, forKey: Key.familiarRegions)
        case .customFactInstructions:
            defaults.set(settings.customFactInstructions, forKey: Key.customFactInstructions)
        case .factInterestCategories:
            defaults.set(
                settings.factInterestCategories.map(\.rawValue).joined(separator: ","),
                forKey: Key.factInterestCategories
            )
        }
    }

    private func loadSpeechProvider() -> SpeechProvider {
        let stored = defaults.string(forKey: Key.speechProvider)
        let provider = stored.flatMap(SpeechProvider.init(rawValue:)) ?? .proxyElevenLabs
        guard defaults.bool(forKey: Key.speechProviderMigration) else {
            defaults.set(SpeechProvider.proxyElevenLabs.rawValue, forKey: Key.speechProvider)
            defaults.set(true, forKey: Key.speechProviderMigration)
            return .proxyElevenLabs
        }
        return provider
    }

    private func loadFactInterestCategories() -> [FactInterestCategory] {
        let values = (defaults.string(forKey: Key.factInterestCategories) ?? "")
            .split(separator: ",")
            .compactMap { rawValue -> FactInterestCategory? in
                let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if normalized == "safetyAdvice" { return .localRidingHints }
                return FactInterestCategory(rawValue: normalized)
            }
        return values.isEmpty ? FactInterestCategory.defaultSelections : values
    }
}

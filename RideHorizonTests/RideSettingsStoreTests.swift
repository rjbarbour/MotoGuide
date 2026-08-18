import XCTest
@testable import RideHorizon

final class RideSettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "RideSettingsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFreshDefaultsMatchCurrentBehaviour() {
        let settings = UserDefaultsRideSettingsStore(defaults: defaults).load()

        XCTAssertEqual(settings.boundarySpeechCooldownSeconds, 10)
        XCTAssertFalse(settings.shortInactivityTimeout)
#if DEBUG
        XCTAssertTrue(settings.testMode)
#else
        XCTAssertFalse(settings.testMode)
#endif
        XCTAssertTrue(settings.interruptsMusic)
        XCTAssertTrue(settings.premiumVoiceAppleFallbackEnabled)
        XCTAssertEqual(settings.preferredVoiceIdentifier, "")
        XCTAssertEqual(settings.speechProvider, .proxyElevenLabs)
        XCTAssertEqual(settings.lastNonQuietContentMode, .shortFacts)
        XCTAssertEqual(settings.homeCountry, "")
        XCTAssertEqual(settings.homeRegion, "")
        XCTAssertEqual(settings.familiarRegions, "")
        XCTAssertEqual(settings.customFactInstructions, "")
        XCTAssertEqual(settings.factInterestCategories, FactInterestCategory.defaultSelections)
    }

    func testPersistedSettingsRoundTripWithoutChangingKeys() {
        let store = UserDefaultsRideSettingsStore(defaults: defaults)
        let settings = RideSettings(
            boundarySpeechCooldownSeconds: 42,
            shortInactivityTimeout: true,
            testMode: false,
            interruptsMusic: false,
            premiumVoiceAppleFallbackEnabled: false,
            preferredVoiceIdentifier: "voice.test",
            speechProvider: .apple,
            lastNonQuietContentMode: .namesOnly,
            homeCountry: "United Kingdom",
            homeRegion: "Surrey",
            familiarRegions: "Cotswolds,Wales",
            customFactInstructions: "Road history",
            factInterestCategories: [.history, .landmarks]
        )

        let fields: [RideSettingField] = [
            .boundarySpeechCooldownSeconds, .shortInactivityTimeout, .testMode,
            .interruptsMusic, .premiumVoiceAppleFallbackEnabled, .preferredVoiceIdentifier,
            .speechProvider, .lastNonQuietContentMode, .homeCountry, .homeRegion, .familiarRegions,
            .customFactInstructions, .factInterestCategories
        ]
        fields.forEach { store.save(settings, changed: $0) }

        XCTAssertEqual(store.load(), settings)
        XCTAssertEqual(defaults.object(forKey: "RideHorizonBoundarySpeechCooldownSeconds") as? Int, 42)
        XCTAssertEqual(defaults.string(forKey: "RideHorizonPreferredVoiceIdentifier"), "voice.test")
        XCTAssertEqual(defaults.string(forKey: "RideHorizonSpeechProvider"), SpeechProvider.apple.rawValue)
        XCTAssertEqual(defaults.string(forKey: "RideHorizonFactInterestCategories"), "history,landmarks")
    }

    func testSpeechProviderMigrationRemainsOneTimeAndPreservesLaterAppleChoice() {
        defaults.set(SpeechProvider.apple.rawValue, forKey: "RideHorizonSpeechProvider")
        let store = UserDefaultsRideSettingsStore(defaults: defaults)

        var settings = store.load()
        XCTAssertEqual(settings.speechProvider, .proxyElevenLabs)
        XCTAssertTrue(defaults.bool(forKey: "RideHorizonSpeechProviderPremiumNoAppleFallbackMigration20260703"))

        settings.speechProvider = .apple
        store.save(settings, changed: .speechProvider)
        XCTAssertEqual(store.load().speechProvider, .apple)
    }

    func testSavingRideSettingsDoesNotPersistSessionOnlyControls() {
        let store = UserDefaultsRideSettingsStore(defaults: defaults)
        let settings = store.load()
        store.save(settings, changed: .homeCountry)

        XCTAssertNil(defaults.object(forKey: "RideHorizonContentMode"))
        XCTAssertNil(defaults.object(forKey: "RideHorizonLocationCheckInterval"))
        XCTAssertNil(defaults.object(forKey: "RideHorizonAnnounceTown"))
        XCTAssertNil(defaults.object(forKey: "RideHorizonBluetoothDelaySeconds"))
        XCTAssertNil(defaults.object(forKey: "RideHorizonSpeakAfterEveryGeocode"))
    }
}

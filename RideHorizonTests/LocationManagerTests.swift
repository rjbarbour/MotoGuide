import XCTest
import CoreLocation
import AVFoundation
@testable import RideHorizon

@MainActor
private final class RecordingSpeechOutputEngine: SpeechOutputEngine {
    struct Request: Equatable {
        let text: String
        let provider: SpeechProvider
        let boundary: BoundaryType?
        let allowAppleFallback: Bool
    }

    var isSpeaking = false
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?
    var onDiagnosticNote: ((String) -> Void)?
    private(set) var requests: [Request] = []
    private(set) var cancelPendingPreparationCount = 0

    func speak(
        text: String,
        boundary: BoundaryType?,
        provider: SpeechProvider,
        appleVoice: AVSpeechSynthesisVoice?,
        allowAppleFallback: Bool
    ) {
        isSpeaking = true
        requests.append(
            Request(
                text: text,
                provider: provider,
                boundary: boundary,
                allowAppleFallback: allowAppleFallback
            )
        )
    }

    func stop() {
        isSpeaking = false
    }

    func cancelPendingPreparation() {
        cancelPendingPreparationCount += 1
        isSpeaking = false
        onCancel?()
    }
}

private final class RecordingAppleSpeechOutput: AppleSpeechOutputting {
    struct Request: Equatable {
        let text: String
        let boundary: BoundaryType?
    }

    var isSpeaking = false
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?
    private(set) var requests: [Request] = []

    func speak(text: String, boundary: BoundaryType?, voice: AVSpeechSynthesisVoice?) {
        requests.append(Request(text: text, boundary: boundary))
    }

    func stop() {
        isSpeaking = false
    }
}

private struct StubProxySpeechGenerator: ProxySpeechGenerating {
    let result: Result<[Data], Error>

    func speechAudios(for text: String) async throws -> [Data] {
        try result.get()
    }
}

private struct DelayedFailingProxySpeechGenerator: ProxySpeechGenerating {
    func speechAudios(for text: String) async throws -> [Data] {
        try await Task.sleep(nanoseconds: 100_000_000)
        throw PlaceFactError.invalidResponse
    }
}

final class LocationManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearLocationManagerDefaults()
        clearSpeechProviderDefaults()
        clearRiderContextDefaults()
    }

    override func tearDown() {
        super.tearDown()
        clearLocationManagerDefaults()
        clearSpeechProviderDefaults()
        clearRiderContextDefaults()
    }

    @MainActor
    func testFreshInstallDefaultsToLiveLocationAndShortFacts() {
        let locationManager = LocationManager()

        XCTAssertFalse(locationManager.testMode)
        XCTAssertEqual(locationManager.contentMode, .shortFacts)
        XCTAssertEqual(locationManager.speechProvider, .proxyElevenLabs)
        XCTAssertTrue(locationManager.interruptsMusic)
        XCTAssertTrue(locationManager.premiumVoiceAppleFallbackEnabled)
    }

    @MainActor
    func testExplicitTestModeChoicePersists() {
        let locationManager = LocationManager()
        locationManager.testMode = true

        let restoredLocationManager = LocationManager()

        XCTAssertTrue(restoredLocationManager.testMode)
    }

    @MainActor
    func testLocationUpdateIntervalThrottlingKeepsVisibleCoordinateFresh() {
        let locationManager = LocationManager()
        locationManager.testMode = false
        locationManager.locationCheckInterval = 60

        let firstLocation = CLLocation(latitude: 51.6971, longitude: -2.5830)
        locationManager.locationManager(CLLocationManager(), didUpdateLocations: [firstLocation])

        XCTAssertEqual(locationManager.lastKnownLocation?.latitude, firstLocation.coordinate.latitude)
        XCTAssertEqual(locationManager.lastKnownLocation?.longitude, firstLocation.coordinate.longitude)

        let secondLocation = CLLocation(latitude: 51.6751, longitude: -2.6210)
        locationManager.locationManager(CLLocationManager(), didUpdateLocations: [secondLocation])

        XCTAssertEqual(locationManager.lastKnownLocation?.latitude, secondLocation.coordinate.latitude)
        XCTAssertEqual(locationManager.lastKnownLocation?.longitude, secondLocation.coordinate.longitude)
    }

    @MainActor
    func testTestModeIgnoresLiveLocationUpdates() {
        let locationManager = LocationManager()
        locationManager.testMode = true

        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        locationManager.locationManager(CLLocationManager(), didUpdateLocations: [location])

        let firstTestWaypoint = TestRouteFixture.waypoints[0]
        XCTAssertEqual(locationManager.lastKnownLocation?.latitude, firstTestWaypoint.latitude)
        XCTAssertEqual(locationManager.lastKnownLocation?.longitude, firstTestWaypoint.longitude)
    }

    @MainActor
    func testClearLocalPrivacyStateRemovesRiderContextAndVisibleRideState() {
        let locationManager = LocationManager()
        locationManager.homeCountry = "United Kingdom"
        locationManager.homeRegion = "Gloucestershire"
        locationManager.familiarRegions = "Cotswolds"
        locationManager.customFactInstructions = "Mention industrial history"
        locationManager.factInterestCategories = [.history]
        locationManager.contentMode = .longFacts
        locationManager.speechProvider = .proxyElevenLabs

        locationManager.clearLocalPrivacyState()

        XCTAssertEqual(locationManager.homeCountry, "")
        XCTAssertEqual(locationManager.homeRegion, "")
        XCTAssertEqual(locationManager.familiarRegions, "")
        XCTAssertEqual(locationManager.customFactInstructions, "")
        XCTAssertEqual(locationManager.factInterestCategories, FactInterestCategory.defaultSelections)
        XCTAssertNil(locationManager.lastKnownLocation)
        XCTAssertNil(locationManager.lastKnownAddress)
        XCTAssertNil(locationManager.lastSpokenPhrase)
        XCTAssertEqual(locationManager.contentMode, .shortFacts)
        XCTAssertEqual(locationManager.speechProvider, .proxyElevenLabs)
        XCTAssertFalse(locationManager.isTracking)
    }

    @MainActor
    func testMovingLocationStillAllowsMapInteraction() {
        let locationManager = LocationManager()
        locationManager.testMode = false

        let movingLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 51.6971, longitude: -2.5830),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 12,
            timestamp: Date()
        )
        locationManager.locationManager(CLLocationManager(), didUpdateLocations: [movingLocation])

        XCTAssertTrue(locationManager.allowsMapInteraction)
    }

    @MainActor
    func testStationaryLocationAllowsMapInteraction() {
        let locationManager = LocationManager()
        locationManager.testMode = false

        let stoppedLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 51.6971, longitude: -2.5830),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 0,
            timestamp: Date()
        )
        locationManager.locationManager(CLLocationManager(), didUpdateLocations: [stoppedLocation])

        XCTAssertTrue(locationManager.allowsMapInteraction)
    }

    @MainActor
    func testLocationFailurePublishesRiderStatus() {
        let locationManager = LocationManager()

        locationManager.locationManager(CLLocationManager(), didFailWithError: CLError(.locationUnknown))

        XCTAssertEqual(locationManager.locationStatus, .locationUnavailable("Location update failed. RideHorizon will keep trying."))
    }

    func testLocationSummaryAndHierarchyUseMapDesignLabels() {
        let address = Address(
            street: "B4066",
            town: "Nailsworth",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        )

        XCTAssertEqual(
            LocationSummaryFormatter.summary(for: address),
            "B4066, Nailsworth, Gloucestershire"
        )

        let rows = LocationSummaryFormatter.hierarchyRows(for: address)
        XCTAssertEqual(rows.map(\.label), ["Street", "Town", "County", "Region", "Country"])
        XCTAssertEqual(rows.map(\.value), ["B4066", "Nailsworth", "Gloucestershire", "England", "United Kingdom"])
        XCTAssertEqual(rows.first?.isCurrent, true)
    }

    @MainActor
    func testPremiumVoiceRoutesEveryBoundaryThroughSelectedSpeechProvider() {
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(speechOutput: speechOutput, aiSharingAllowed: { true })
        locationManager.speechProvider = .proxyElevenLabs

        for boundary in BoundaryType.allCases {
            locationManager.speakForTesting(text: "Boundary test for \(boundary.factLabel)", boundary: boundary)
        }

        XCTAssertEqual(speechOutput.requests.map(\.provider), Array(repeating: .proxyElevenLabs, count: BoundaryType.allCases.count))
        XCTAssertEqual(speechOutput.requests.map(\.boundary), BoundaryType.allCases)
    }

    @MainActor
    func testLegacyAppleSpeechProviderDefaultMigratesToPremiumVoiceForAnnouncements() {
        clearSpeechProviderDefaults()
        UserDefaults.standard.set("apple", forKey: "RideHorizonSpeechProvider")

        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(speechOutput: speechOutput, aiSharingAllowed: { true })

        locationManager.speakForTesting(text: "Boundary test for town", boundary: .town)

        XCTAssertEqual(locationManager.speechProvider, .proxyElevenLabs)
        XCTAssertEqual(speechOutput.requests.last?.provider, .proxyElevenLabs)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "RideHorizonSpeechProvider"), "proxyElevenLabs")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "RideHorizonSpeechProviderPremiumNoAppleFallbackMigration20260703"))
    }

    @MainActor
    func testAppleSpeechProviderPersistsAfterPremiumDefaultMigration() {
        clearSpeechProviderDefaults()
        UserDefaults.standard.set("apple", forKey: "RideHorizonSpeechProvider")
        UserDefaults.standard.set(true, forKey: "RideHorizonSpeechProviderPremiumNoAppleFallbackMigration20260703")

        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(speechOutput: speechOutput, aiSharingAllowed: { true })

        locationManager.speakForTesting(text: "Boundary test for town", boundary: .town)

        XCTAssertEqual(locationManager.speechProvider, .apple)
        XCTAssertEqual(speechOutput.requests.last?.provider, .apple)
    }

    @MainActor
    func testTestModeDoesNotEnablePremiumVoiceAppleFallbackByDefault() {
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(speechOutput: speechOutput, aiSharingAllowed: { true })
        locationManager.testMode = true
        locationManager.premiumVoiceAppleFallbackEnabled = false

        locationManager.speakForTesting(text: "Boundary test for town", boundary: .town)

        XCTAssertEqual(speechOutput.requests.last?.provider, .proxyElevenLabs)
        XCTAssertEqual(speechOutput.requests.last?.allowAppleFallback, false)
    }

    @MainActor
    func testPremiumVoiceAppleFallbackFeatureFlagControlsSpeechFallback() {
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(speechOutput: speechOutput, aiSharingAllowed: { true })
        locationManager.testMode = true
        locationManager.premiumVoiceAppleFallbackEnabled = true

        locationManager.speakForTesting(text: "Boundary test for town", boundary: .town)

        XCTAssertEqual(speechOutput.requests.last?.provider, .proxyElevenLabs)
        XCTAssertEqual(speechOutput.requests.last?.allowAppleFallback, true)
    }

    @MainActor
    func testPremiumVoiceDoesNotFallbackToAppleWhenProxyFails() async {
        let appleSpeechOutput = RecordingAppleSpeechOutput()
        let speechOutput = DefaultSpeechOutputEngine(
            proxySpeechGenerator: StubProxySpeechGenerator(result: .failure(PlaceFactError.invalidResponse)),
            appleSpeechOutput: appleSpeechOutput
        )
        let finished = expectation(description: "Premium voice failure finishes without Apple fallback")
        var diagnosticNote: String?
        speechOutput.onFinish = {
            finished.fulfill()
        }
        speechOutput.onDiagnosticNote = { note in
            diagnosticNote = note
        }

        speechOutput.speak(
            text: "Known for its market square.",
            boundary: .town,
            provider: .proxyElevenLabs,
            appleVoice: nil,
            allowAppleFallback: false
        )

        await fulfillment(of: [finished], timeout: 1.0)
        XCTAssertTrue(appleSpeechOutput.requests.isEmpty)
        XCTAssertEqual(diagnosticNote, "Premium voice failed: invalid proxy response. Apple fallback disabled.")
    }

    @MainActor
    func testPremiumVoiceShowsOnlyOpaqueProviderDiagnosticCode() async {
        let appleSpeechOutput = RecordingAppleSpeechOutput()
        let speechOutput = DefaultSpeechOutputEngine(
            proxySpeechGenerator: StubProxySpeechGenerator(
                result: .failure(PlaceFactError.speechServiceUnavailable(code: "RH-TTS-02"))
            ),
            appleSpeechOutput: appleSpeechOutput
        )
        let finished = expectation(description: "Coded premium voice failure finishes")
        var diagnosticNote: String?
        speechOutput.onFinish = {
            finished.fulfill()
        }
        speechOutput.onDiagnosticNote = { note in
            diagnosticNote = note
        }

        speechOutput.speak(
            text: "Known for its market square.",
            boundary: .town,
            provider: .proxyElevenLabs,
            appleVoice: nil,
            allowAppleFallback: false
        )

        await fulfillment(of: [finished], timeout: 1.0)
        XCTAssertTrue(appleSpeechOutput.requests.isEmpty)
        XCTAssertEqual(
            diagnosticNote,
            "Premium voice failed: Premium voice is temporarily unavailable. [RH-TTS-02]. Apple fallback disabled."
        )
        XCTAssertFalse(diagnosticNote?.localizedCaseInsensitiveContains("credit") == true)
        XCTAssertFalse(diagnosticNote?.localizedCaseInsensitiveContains("quota") == true)
    }

    @MainActor
    func testPremiumVoiceDoesNotFallbackToAppleWhenProxyReturnsNoAudio() async {
        let appleSpeechOutput = RecordingAppleSpeechOutput()
        let speechOutput = DefaultSpeechOutputEngine(
            proxySpeechGenerator: StubProxySpeechGenerator(result: .success([])),
            appleSpeechOutput: appleSpeechOutput
        )
        let finished = expectation(description: "Empty premium voice response finishes without Apple fallback")
        speechOutput.onFinish = {
            finished.fulfill()
        }

        speechOutput.speak(
            text: "Known for its market square.",
            boundary: .town,
            provider: .proxyElevenLabs,
            appleVoice: nil,
            allowAppleFallback: false
        )

        await fulfillment(of: [finished], timeout: 1.0)
        XCTAssertTrue(appleSpeechOutput.requests.isEmpty)
    }

    @MainActor
    func testPremiumVoiceUsesAppleFallbackWhenFeatureFlagAllowsIt() async {
        let appleSpeechOutput = RecordingAppleSpeechOutput()
        let speechOutput = DefaultSpeechOutputEngine(
            proxySpeechGenerator: StubProxySpeechGenerator(result: .failure(PlaceFactError.invalidResponse)),
            appleSpeechOutput: appleSpeechOutput
        )
        var diagnosticNote: String?
        speechOutput.onDiagnosticNote = { note in
            diagnosticNote = note
        }

        speechOutput.speak(
            text: "Known for its market square.",
            boundary: .town,
            provider: .proxyElevenLabs,
            appleVoice: nil,
            allowAppleFallback: true
        )

        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(appleSpeechOutput.requests.map(\.text), ["Known for its market square."])
        XCTAssertEqual(appleSpeechOutput.requests.map(\.boundary), [.town])
        XCTAssertTrue(diagnosticNote?.hasPrefix("Premium voice failed:") == true)
        XCTAssertTrue(diagnosticNote?.hasSuffix("Apple fallback used.") == true)
    }

    @MainActor
    func testSupersededPremiumVoiceRequestDoesNotTriggerDelayedAppleFallback() async {
        let appleSpeechOutput = RecordingAppleSpeechOutput()
        let speechOutput = DefaultSpeechOutputEngine(
            proxySpeechGenerator: DelayedFailingProxySpeechGenerator(),
            appleSpeechOutput: appleSpeechOutput
        )
        var diagnosticNote: String?
        speechOutput.onDiagnosticNote = { note in
            diagnosticNote = note
        }

        speechOutput.speak(
            text: "This announcement will be superseded.",
            boundary: .town,
            provider: .proxyElevenLabs,
            appleVoice: nil,
            allowAppleFallback: true
        )
        try? await Task.sleep(nanoseconds: 20_000_000)
        speechOutput.stop()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(appleSpeechOutput.requests.isEmpty)
        XCTAssertNil(diagnosticNote)
    }

    @MainActor
    func testPremiumVoiceReportsActiveWhileWaitingForNetworkAudio() {
        let speechOutput = DefaultSpeechOutputEngine(
            proxySpeechGenerator: DelayedFailingProxySpeechGenerator(),
            appleSpeechOutput: RecordingAppleSpeechOutput()
        )

        speechOutput.speak(
            text: "Waiting for network audio.",
            boundary: .town,
            provider: .proxyElevenLabs,
            appleVoice: nil,
            allowAppleFallback: false
        )

        XCTAssertTrue(speechOutput.isSpeaking)
        speechOutput.stop()
    }

    @MainActor
    func testAppleProviderUsesAppleSpeechOutputOnlyWhenExplicitlySelected() {
        let appleSpeechOutput = RecordingAppleSpeechOutput()
        let speechOutput = DefaultSpeechOutputEngine(
            proxySpeechGenerator: StubProxySpeechGenerator(result: .failure(PlaceFactError.invalidResponse)),
            appleSpeechOutput: appleSpeechOutput
        )

        speechOutput.speak(
            text: "Known for its market square.",
            boundary: .town,
            provider: .apple,
            appleVoice: nil,
            allowAppleFallback: false
        )

        XCTAssertEqual(appleSpeechOutput.requests.map(\.text), ["Known for its market square."])
        XCTAssertEqual(appleSpeechOutput.requests.map(\.boundary), [.town])
    }

    @MainActor
    func testDeclinedAISharingSkipsFactProviderAndForcesAppleSpeech() async {
        let factGenerator = MockPlaceFactGenerator()
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(
            factGenerator: factGenerator,
            speechOutput: speechOutput,
            aiSharingAllowed: { false }
        )
        locationManager.testMode = false
        locationManager.contentMode = .shortFacts
        locationManager.speechProvider = .proxyElevenLabs
        locationManager.bluetoothDelaySeconds = 0

        locationManager.processResolvedAddressForTesting(Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        locationManager.processResolvedAddressForTesting(Address(
            street: "Bristol Road",
            town: "Stonehouse",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(factGenerator.callCount, 0)
        XCTAssertEqual(speechOutput.requests.last?.provider, .apple)
        XCTAssertEqual(speechOutput.requests.last?.text, "You are in Stonehouse, Gloucestershire")
    }

    @MainActor
    func testNewSuppressedBoundaryCancelsOlderFactInsteadOfSpeakingStalePlace() async {
        let factGenerator = MockPlaceFactGenerator()
        factGenerator.delayNanoseconds = 150_000_000
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(
            factGenerator: factGenerator,
            speechOutput: speechOutput,
            aiSharingAllowed: { true }
        )
        locationManager.testMode = false
        locationManager.contentMode = .shortFacts
        locationManager.boundarySpeechCooldownSeconds = 60
        locationManager.bluetoothDelaySeconds = 0

        let stroud = Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        )
        let stonehouse = Address(
            street: "Bristol Road",
            town: "Stonehouse",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        )
        let dursley = Address(
            street: "Long Street",
            town: "Dursley",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        )
        let stonehouseRequest = AnnouncementPolicy.factRequest(
            for: AnnouncementPlan(text: "You are in Stonehouse, Gloucestershire", boundary: .town),
            address: stonehouse,
            mode: .shortFacts,
            riderContext: .empty
        )
        factGenerator.factsByCacheKey[stonehouseRequest.cacheKey] = "Known for its canal-side industry."

        locationManager.processResolvedAddressForTesting(stroud)
        locationManager.processResolvedAddressForTesting(stonehouse)
        locationManager.processResolvedAddressForTesting(dursley)
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(speechOutput.requests.isEmpty)
    }

    @MainActor
    func testStreetOnlyGeocoderChangeDoesNotCancelTownFact() async {
        let factGenerator = MockPlaceFactGenerator()
        factGenerator.delayNanoseconds = 150_000_000
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(
            factGenerator: factGenerator,
            speechOutput: speechOutput,
            aiSharingAllowed: { true }
        )
        locationManager.testMode = false
        locationManager.contentMode = .shortFacts
        locationManager.boundarySpeechCooldownSeconds = 0
        locationManager.bluetoothDelaySeconds = 0

        locationManager.processResolvedAddressForTesting(Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        locationManager.processResolvedAddressForTesting(Address(
            street: "Bristol Road",
            town: "Stonehouse",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        locationManager.processResolvedAddressForTesting(Address(
            street: "Bath Road",
            town: "Stonehouse",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(speechOutput.requests.last?.boundary, .town)
        XCTAssertEqual(speechOutput.requests.last?.text, "You are in Stonehouse, Gloucestershire")
    }

    @MainActor
    func testLowerPriorityTownDoesNotCancelHigherPriorityCountryFact() async {
        let factGenerator = MockPlaceFactGenerator()
        factGenerator.delayNanoseconds = 150_000_000
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(
            factGenerator: factGenerator,
            speechOutput: speechOutput,
            aiSharingAllowed: { true }
        )
        locationManager.testMode = false
        locationManager.contentMode = .shortFacts
        locationManager.boundarySpeechCooldownSeconds = 0
        locationManager.bluetoothDelaySeconds = 0

        locationManager.processResolvedAddressForTesting(Address(
            street: "High Street",
            town: "Dover",
            county: "Kent",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        locationManager.processResolvedAddressForTesting(Address(
            street: "Rue de Paris",
            town: "Calais",
            county: "Pas-de-Calais",
            administrativeArea: "Hauts-de-France",
            country: "France"
        ))
        locationManager.processResolvedAddressForTesting(Address(
            street: "Rue Royale",
            town: "Lille",
            county: "Nord",
            administrativeArea: "Hauts-de-France",
            country: "France"
        ))
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(speechOutput.requests.count, 1)
        XCTAssertEqual(speechOutput.requests.first?.boundary, .country)
        XCTAssertTrue(speechOutput.requests.first?.text.hasPrefix("Welcome to France.") == true)
    }

    @MainActor
    func testNewBoundaryCancelsOlderSpeechPreparationBeforeQueuingReplacement() async {
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(speechOutput: speechOutput, aiSharingAllowed: { true })
        locationManager.testMode = false
        locationManager.contentMode = .namesOnly
        locationManager.boundarySpeechCooldownSeconds = 0
        locationManager.bluetoothDelaySeconds = 0

        locationManager.processResolvedAddressForTesting(Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        locationManager.processResolvedAddressForTesting(Address(
            street: "Bristol Road",
            town: "Stonehouse",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        try? await Task.sleep(nanoseconds: 50_000_000)
        let cancellationsBeforeNewBoundary = speechOutput.cancelPendingPreparationCount

        locationManager.processResolvedAddressForTesting(Address(
            street: "Long Street",
            town: "Dursley",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))

        XCTAssertEqual(
            speechOutput.cancelPendingPreparationCount,
            cancellationsBeforeNewBoundary + 1
        )
    }

    private func clearSpeechProviderDefaults() {
        UserDefaults.standard.removeObject(forKey: "RideHorizonSpeechProvider")
        UserDefaults.standard.removeObject(forKey: "RideHorizonSpeechProviderPremiumNoAppleFallbackMigration20260703")
        UserDefaults.standard.removeObject(forKey: "RideHorizonPremiumVoiceAppleFallbackEnabled")
    }

    private func clearLocationManagerDefaults() {
        [
            "RideHorizonTestMode",
            "RideHorizonInterruptsMusic"
        ].forEach(UserDefaults.standard.removeObject(forKey:))
    }

    private func clearRiderContextDefaults() {
        [
            "RideHorizonHomeCountry",
            "RideHorizonHomeRegion",
            "RideHorizonFamiliarRegions",
            "RideHorizonCustomFactInstructions",
            "RideHorizonFactInterestCategories"
        ].forEach(UserDefaults.standard.removeObject(forKey:))
    }
}

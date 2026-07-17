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

    func speak(
        text: String,
        boundary: BoundaryType?,
        provider: SpeechProvider,
        appleVoice: AVSpeechSynthesisVoice?,
        allowAppleFallback: Bool
    ) {
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

final class LocationManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearSpeechProviderDefaults()
    }

    override func tearDown() {
        super.tearDown()
        clearSpeechProviderDefaults()
    }

    @MainActor
    func testDefaultsUseMVPRealRideModeAndShortFacts() {
        let locationManager = LocationManager()

        XCTAssertFalse(locationManager.testMode)
        XCTAssertEqual(locationManager.contentMode, .shortFacts)
        XCTAssertEqual(locationManager.speechProvider, .proxyElevenLabs)
        XCTAssertTrue(locationManager.interruptsMusic)
        XCTAssertFalse(locationManager.premiumVoiceAppleFallbackEnabled)
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

        XCTAssertNil(locationManager.lastKnownLocation)
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
        let locationManager = LocationManager(speechOutput: speechOutput)
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
        let locationManager = LocationManager(speechOutput: speechOutput)

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
        let locationManager = LocationManager(speechOutput: speechOutput)

        locationManager.speakForTesting(text: "Boundary test for town", boundary: .town)

        XCTAssertEqual(locationManager.speechProvider, .apple)
        XCTAssertEqual(speechOutput.requests.last?.provider, .apple)
    }

    @MainActor
    func testTestModeDoesNotEnablePremiumVoiceAppleFallbackByDefault() {
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(speechOutput: speechOutput)
        locationManager.testMode = true
        locationManager.premiumVoiceAppleFallbackEnabled = false

        locationManager.speakForTesting(text: "Boundary test for town", boundary: .town)

        XCTAssertEqual(speechOutput.requests.last?.provider, .proxyElevenLabs)
        XCTAssertEqual(speechOutput.requests.last?.allowAppleFallback, false)
    }

    @MainActor
    func testPremiumVoiceAppleFallbackFeatureFlagControlsSpeechFallback() {
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(speechOutput: speechOutput)
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
            "Premium voice failed: Premium voice is temporarily unavailable. [RH-TTS-02] Apple fallback disabled."
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

    private func clearSpeechProviderDefaults() {
        UserDefaults.standard.removeObject(forKey: "RideHorizonSpeechProvider")
        UserDefaults.standard.removeObject(forKey: "RideHorizonSpeechProviderPremiumNoAppleFallbackMigration20260703")
        UserDefaults.standard.removeObject(forKey: "RideHorizonPremiumVoiceAppleFallbackEnabled")
    }
}

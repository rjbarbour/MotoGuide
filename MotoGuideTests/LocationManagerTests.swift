import XCTest
import CoreLocation
import AVFoundation
@testable import MotoGuide

@MainActor
private final class RecordingSpeechOutputEngine: SpeechOutputEngine {
    struct Request: Equatable {
        let text: String
        let provider: SpeechProvider
        let boundary: BoundaryType?
    }

    var isSpeaking = false
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?
    private(set) var requests: [Request] = []

    func speak(text: String, boundary: BoundaryType?, provider: SpeechProvider, appleVoice: AVSpeechSynthesisVoice?) {
        requests.append(Request(text: text, provider: provider, boundary: boundary))
    }

    func stop() {
        isSpeaking = false
    }
}

final class LocationManagerTests: XCTestCase {
    @MainActor
    func testDefaultsUseMVPRealRideModeAndShortFacts() {
        let locationManager = LocationManager()

        XCTAssertFalse(locationManager.testMode)
        XCTAssertEqual(locationManager.contentMode, .shortFacts)
        XCTAssertEqual(locationManager.speechProvider, .proxyElevenLabs)
        XCTAssertTrue(locationManager.interruptsMusic)
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

        XCTAssertEqual(locationManager.locationStatus, .locationUnavailable("Location update failed. MotoGuide will keep trying."))
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
}

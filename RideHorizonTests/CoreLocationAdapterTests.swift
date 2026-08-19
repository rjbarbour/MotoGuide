import XCTest
import CoreLocation
@testable import RideHorizon

@MainActor
private final class RecordingLocationSource: LocationSource {
    var authorizationStatus: CLAuthorizationStatus = .authorizedAlways
    var onLocations: (([CLLocation]) -> Void)?
    var onFailure: ((Error) -> Void)?
    var onAuthorizationChange: (() -> Void)?
    private(set) var startBackgroundValues: [Bool] = []
    private(set) var stopCount = 0
    func requestLocation() {}
    func requestAlwaysAuthorization() {}
    func start(backgroundUpdates: Bool) { startBackgroundValues.append(backgroundUpdates) }
    func stop() { stopCount += 1 }
    func emit(_ location: CLLocation) { onLocations?([location]) }
}

@MainActor
private final class RecordingPlaceResolver: PlaceResolver {
    private(set) var locations: [AcceptedRideLocation] = []
    private(set) var cancelCount = 0
    private var completion: ((PlaceResolutionResult) -> Void)?
    func resolve(_ location: AcceptedRideLocation, completion: @escaping (PlaceResolutionResult) -> Void) {
        locations.append(location)
        self.completion = completion
    }
    func cancel() { cancelCount += 1 }
    func complete(with result: PlaceResolutionResult) { completion?(result) }
}

@MainActor
final class CoreLocationAdapterTests: XCTestCase {
    func testInitialisationOwnsProductionConfiguration() {
        let manager = CLLocationManager()
        let adapter = CoreLocationAdapter(manager: manager, geocoder: CLGeocoder())

        XCTAssertTrue(manager.delegate === adapter)
        XCTAssertEqual(manager.desiredAccuracy, kCLLocationAccuracyBest)
        XCTAssertFalse(manager.pausesLocationUpdatesAutomatically)
    }

    func testDelegateCallbacksTranslateToConsumerClosures() {
        let manager = CLLocationManager()
        let adapter = CoreLocationAdapter(manager: manager, geocoder: CLGeocoder())
        let location = CLLocation(latitude: 51.75, longitude: -2.22)
        var receivedLocations: [CLLocation] = []
        var receivedError: Error?
        var authorizationChangeCount = 0
        adapter.onLocations = { receivedLocations = $0 }
        adapter.onFailure = { receivedError = $0 }
        adapter.onAuthorizationChange = { authorizationChangeCount += 1 }
        let error = CLError(.locationUnknown)

        adapter.locationManager(manager, didUpdateLocations: [location])
        adapter.locationManager(manager, didFailWithError: error)
        adapter.locationManagerDidChangeAuthorization(manager)

        XCTAssertEqual(receivedLocations, [location])
        XCTAssertEqual((receivedError as? CLError)?.code, .locationUnknown)
        XCTAssertEqual(authorizationChangeCount, 1)
    }

    func testRideDistanceMeasurerUsesCoreLocationDistanceAtTheMovementBoundary() {
        let recordedAt = Date(timeIntervalSince1970: 1_000)
        let first = AcceptedRideLocation(
            latitude: 51,
            longitude: 0,
            horizontalAccuracy: 5,
            recordedAt: recordedAt,
            acceptedAt: recordedAt
        )
        let second = AcceptedRideLocation(
            latitude: 51.00054,
            longitude: 0,
            horizontalAccuracy: 5,
            recordedAt: recordedAt,
            acceptedAt: recordedAt
        )
        let expected = CLLocation(latitude: first.latitude, longitude: first.longitude).distance(
            from: CLLocation(latitude: second.latitude, longitude: second.longitude)
        )

        XCTAssertEqual(
            CoreLocationRideDistanceMeasurer().distance(from: first, to: second),
            expected,
            accuracy: 0.000_001
        )
        XCTAssertGreaterThan(expected - first.horizontalAccuracy - second.horizontalAccuracy, 50)
    }
}

@MainActor
final class RideSessionAdapterContractTests: XCTestCase {
    func testRideStartedWithoutLocationInputIgnoresLaterAuthorizationChanges() {
        let source = RecordingLocationSource()
        let resolver = RecordingPlaceResolver()
        let manager = LocationManager(
            locationSource: source,
            placeResolver: resolver,
            rideDistanceMeasurer: CoreLocationRideDistanceMeasurer()
        )
        manager.testMode = false

        manager.startRideWithoutLocationInputForTesting()
        source.onAuthorizationChange?()

        XCTAssertTrue(source.startBackgroundValues.isEmpty)
    }

    func testLocationAndPlaceAdaptersAreDeterministicRideCapabilities() async {
        let source = RecordingLocationSource()
        let resolver = RecordingPlaceResolver()
        let manager = LocationManager(
            locationSource: source,
            placeResolver: resolver,
            rideDistanceMeasurer: CoreLocationRideDistanceMeasurer()
        )
        manager.testMode = false
        manager.locationCheckInterval = 0
        let startedAt = Date()
        manager.startRide(at: startedAt)

        XCTAssertEqual(source.startBackgroundValues, [true])

        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 51.75, longitude: -2.22),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 10,
            timestamp: startedAt
        )
        source.emit(location)
        XCTAssertEqual(resolver.locations.count, 1)

        let address = Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        )
        resolver.complete(with: .resolved(address))
        await Task.yield()
        XCTAssertEqual(manager.lastKnownAddress, address)

        manager.endRide()
        XCTAssertEqual(source.stopCount, 1)
        XCTAssertGreaterThanOrEqual(resolver.cancelCount, 1)
    }

    func testPlaceResultAfterRideEndCannotMutatePublishedState() async {
        let source = RecordingLocationSource()
        let resolver = RecordingPlaceResolver()
        let manager = LocationManager(
            locationSource: source,
            placeResolver: resolver,
            rideDistanceMeasurer: CoreLocationRideDistanceMeasurer()
        )
        manager.testMode = false
        manager.locationCheckInterval = 0
        let startedAt = Date()
        manager.startRide(at: startedAt)
        source.emit(CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 51.75, longitude: -2.22),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 10,
            timestamp: startedAt
        ))

        manager.endRide()
        resolver.complete(with: .resolved(Address(
            street: "Late Street",
            town: "Late Town",
            county: "Late County",
            administrativeArea: "England",
            country: "United Kingdom"
        )))
        await Task.yield()

        XCTAssertNil(manager.lastKnownAddress)
    }
}

import CoreLocation
import XCTest
@testable import RideHorizon

final class RideSessionLifecycleTests: XCTestCase {
    func testStartAndManualEndBoundTheRideSession() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var lifecycle = RideSessionLifecycle()

        XCTAssertEqual(lifecycle.state, .idle)

        lifecycle.start(at: startedAt)
        XCTAssertEqual(lifecycle.state, .riding)

        lifecycle.end()
        XCTAssertEqual(lifecycle.state, .idle)
    }

    func testTenMinutesWithoutConfirmedMovementRequestsConfirmation() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var lifecycle = RideSessionLifecycle()
        lifecycle.start(at: startedAt)

        let transition = lifecycle.advanceTime(to: startedAt.addingTimeInterval(600))

        XCTAssertEqual(
            transition,
            .inactivityPrompt(deadline: startedAt.addingTimeInterval(720))
        )
        XCTAssertEqual(
            lifecycle.state,
            .awaitingConfirmation(deadline: startedAt.addingTimeInterval(720))
        )
    }

    func testConfidenceAdjustedMovementResetsTheInactivityWindow() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var lifecycle = RideSessionLifecycle()
        lifecycle.start(at: startedAt)
        lifecycle.observe(
            location(latitude: 51, longitude: 0, accuracy: 5, timestamp: startedAt),
            at: startedAt
        )

        let movementTime = startedAt.addingTimeInterval(599)
        let transition = lifecycle.observe(
            location(latitude: 51.0007, longitude: 0, accuracy: 5, timestamp: movementTime),
            at: movementTime
        )

        XCTAssertEqual(transition, .none)
        XCTAssertEqual(
            lifecycle.advanceTime(to: movementTime.addingTimeInterval(599)),
            .none
        )
        XCTAssertEqual(lifecycle.state, .riding)
    }

    func testContinueRideStartsAFreshInactivityWindow() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var lifecycle = RideSessionLifecycle()
        lifecycle.start(at: startedAt)
        _ = lifecycle.advanceTime(to: startedAt.addingTimeInterval(600))

        let continuedAt = startedAt.addingTimeInterval(660)
        lifecycle.continueRide(at: continuedAt)

        XCTAssertEqual(lifecycle.state, .riding)
        XCTAssertEqual(
            lifecycle.advanceTime(to: continuedAt.addingTimeInterval(599)),
            .none
        )
    }

    func testContinueRideRejectsAnExpiredConfirmation() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var lifecycle = RideSessionLifecycle()
        lifecycle.start(at: startedAt)
        _ = lifecycle.advanceTime(to: startedAt.addingTimeInterval(600))

        let continued = lifecycle.continueRide(at: startedAt.addingTimeInterval(721))

        XCTAssertFalse(continued)
        XCTAssertEqual(lifecycle.state, .idle)
    }

    func testUnansweredPromptEndsTheRideAtTheGraceDeadline() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var lifecycle = RideSessionLifecycle()
        lifecycle.start(at: startedAt)
        _ = lifecycle.advanceTime(to: startedAt.addingTimeInterval(600))

        let transition = lifecycle.advanceTime(to: startedAt.addingTimeInterval(720))

        XCTAssertEqual(transition, .automaticEnd)
        XCTAssertEqual(lifecycle.state, .idle)
    }

    func testStaleOrInaccurateSamplesDoNotKeepTheRideAlive() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var lifecycle = RideSessionLifecycle()
        lifecycle.start(at: startedAt)
        lifecycle.observe(
            location(latitude: 51, longitude: 0, accuracy: 5, timestamp: startedAt),
            at: startedAt
        )

        let nearDeadline = startedAt.addingTimeInterval(599)
        lifecycle.observe(
            location(latitude: 52, longitude: 0, accuracy: 31, timestamp: nearDeadline),
            at: nearDeadline
        )
        lifecycle.observe(
            location(latitude: 52, longitude: 0, accuracy: 5, timestamp: startedAt),
            at: nearDeadline
        )

        XCTAssertEqual(
            lifecycle.advanceTime(to: startedAt.addingTimeInterval(600)),
            .inactivityPrompt(deadline: startedAt.addingTimeInterval(720))
        )
    }

    func testConfirmedMovementDuringGraceResumesWithoutInteraction() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var lifecycle = RideSessionLifecycle()
        lifecycle.start(at: startedAt)
        lifecycle.observe(
            location(latitude: 51, longitude: 0, accuracy: 5, timestamp: startedAt),
            at: startedAt
        )
        _ = lifecycle.advanceTime(to: startedAt.addingTimeInterval(600))

        let resumedAt = startedAt.addingTimeInterval(660)
        let transition = lifecycle.observe(
            location(latitude: 51.0007, longitude: 0, accuracy: 5, timestamp: resumedAt),
            at: resumedAt
        )

        XCTAssertEqual(transition, .movementResumed)
        XCTAssertEqual(lifecycle.state, .riding)
    }

    private func location(
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        accuracy: CLLocationAccuracy,
        timestamp: Date
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 5,
            course: 0,
            speed: 0,
            timestamp: timestamp
        )
    }
}

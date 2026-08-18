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

    func testCustomShortTimingUsesTheSameInactivityAndGraceTransitions() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var lifecycle = RideSessionLifecycle(
            inactivityInterval: 30,
            confirmationGracePeriod: 30
        )
        lifecycle.start(at: startedAt)

        XCTAssertEqual(
            lifecycle.advanceTime(to: startedAt.addingTimeInterval(29)),
            .none
        )
        XCTAssertEqual(
            lifecycle.advanceTime(to: startedAt.addingTimeInterval(30)),
            .inactivityPrompt(deadline: startedAt.addingTimeInterval(60))
        )
        XCTAssertEqual(
            lifecycle.advanceTime(to: startedAt.addingTimeInterval(60)),
            .automaticEnd
        )
        XCTAssertEqual(lifecycle.state, .idle)
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

@MainActor
final class RideSessionControllerTests: XCTestCase {
    func testStartSchedulesEvaluationAndEndInvalidatesGeneration() {
        let now = Date(timeIntervalSince1970: 1_000)
        let scheduler = RecordingRideSessionScheduler()
        let controller = RideSessionController(
            clock: FixedRideClock(now: now),
            scheduler: scheduler
        )
        var scheduledTransitions: [RideSessionTransition] = []

        let start = controller.start(wantsLocationInput: true) {
            scheduledTransitions.append($0)
        }

        XCTAssertEqual(start?.startedAt, now)
        XCTAssertEqual(controller.state, .riding)
        XCTAssertEqual(scheduler.interval, 15)
        scheduler.fire()
        XCTAssertEqual(scheduledTransitions, [.none])

        let originalGeneration = controller.generation
        let end = controller.end()
        XCTAssertTrue(end.wasActive)
        XCTAssertNotEqual(controller.generation, originalGeneration)
        XCTAssertEqual(controller.state, .idle)
        XCTAssertTrue(scheduler.didCancel)
    }

    func testAcceptedLocationAndInactivityRemainDeterministic() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let controller = RideSessionController(
            clock: FixedRideClock(now: startedAt),
            scheduler: RecordingRideSessionScheduler(),
            lifecycle: RideSessionLifecycle(inactivityInterval: 30, confirmationGracePeriod: 30)
        )
        _ = controller.start(wantsLocationInput: true) { _ in }

        let transition = controller.accept(
            AcceptedRideLocation(
                location: location(timestamp: startedAt),
                acceptedAt: startedAt
            )
        )

        XCTAssertEqual(transition, .none)
        XCTAssertEqual(
            controller.evaluate(at: startedAt.addingTimeInterval(30)),
            .inactivityPrompt(deadline: startedAt.addingTimeInterval(60))
        )
        XCTAssertTrue(controller.continueRide(at: startedAt.addingTimeInterval(45)))
        XCTAssertEqual(controller.state, .riding)
    }

    func testStaleRequestIsRejectedAfterEndAndRestart() {
        let scheduler = RecordingRideSessionScheduler()
        let controller = RideSessionController(scheduler: scheduler)
        _ = controller.start(wantsLocationInput: true) { _ in }
        let staleGeneration = controller.generation
        let requestGeneration = UUID()

        XCTAssertTrue(controller.accepts(
            rideGeneration: staleGeneration,
            requestGeneration: requestGeneration,
            currentRequestGeneration: requestGeneration
        ))

        _ = controller.end()
        _ = controller.start(wantsLocationInput: true) { _ in }

        XCTAssertFalse(controller.accepts(
            rideGeneration: staleGeneration,
            requestGeneration: requestGeneration,
            currentRequestGeneration: requestGeneration
        ))
    }

    private func location(timestamp: Date) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 51, longitude: 0),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 0,
            timestamp: timestamp
        )
    }
}

private struct FixedRideClock: RideClock {
    let now: Date
}

@MainActor
private final class RecordingRideSessionScheduler: RideSessionScheduling {
    private var action: (@MainActor () -> Void)?
    private(set) var interval: TimeInterval?
    private(set) var didCancel = false

    func scheduleRepeating(every interval: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        self.interval = interval
        self.action = action
        didCancel = false
    }

    func cancel() {
        action = nil
        didCancel = true
    }

    func fire() {
        action?()
    }
}

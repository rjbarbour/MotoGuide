import XCTest
@testable import RideHorizon

@MainActor
final class RideSessionControllerTests: XCTestCase {
    func testStartSchedulesEvaluationAndEndInvalidatesGeneration() {
        let now = Date(timeIntervalSince1970: 1_000)
        let scheduler = RecordingRideSessionScheduler()
        let controller = RideSessionController(
            clock: FixedRideClock(now: now),
            scheduler: scheduler
        )
        var scheduledTransitions: [RideSessionControllerTransition] = []

        let start = controller.start(wantsLocationInput: true) {
            scheduledTransitions.append($0)
        }

        XCTAssertEqual(start?.startedAt, now)
        XCTAssertEqual(
            start?.effects,
            [.requestInactivityAuthorization, .refreshLocationInput]
        )
        XCTAssertEqual(controller.state, .riding)
        XCTAssertEqual(scheduler.interval, 15)
        scheduler.fire()
        XCTAssertEqual(
            scheduledTransitions,
            [RideSessionControllerTransition(transition: .none, cancellationIntent: nil)]
        )

        let originalGeneration = controller.generation
        let end = controller.end()
        XCTAssertTrue(end.wasActive)
        XCTAssertNotEqual(controller.generation, originalGeneration)
        XCTAssertEqual(controller.state, .idle)
        XCTAssertTrue(scheduler.didCancel)
        XCTAssertEqual(end.cancellationIntent, .rideEnded(wasActive: true))
    }

    func testAcceptedLocationAndInactivityRemainDeterministic() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let controller = RideSessionController(
            clock: FixedRideClock(now: startedAt),
            scheduler: RecordingRideSessionScheduler(),
            lifecycle: RideSessionLifecycle(inactivityInterval: 30, confirmationGracePeriod: 30)
        )
        _ = controller.start(wantsLocationInput: true) { _ in }

        let transition = controller.accept(location(recordedAt: startedAt, acceptedAt: startedAt))

        XCTAssertEqual(transition.transition, .none)
        let prompt = controller.evaluate(at: startedAt.addingTimeInterval(30))
        XCTAssertEqual(prompt.transition, .inactivityPrompt(deadline: startedAt.addingTimeInterval(60)))
        XCTAssertEqual(prompt.cancellationIntent, .inactivityPrompted)
        XCTAssertEqual(prompt.effects, [
            .cancelRideWork(.inactivityPrompted),
            .showInactivityPrompt(deadline: startedAt.addingTimeInterval(60))
        ])
        XCTAssertEqual(
            controller.continueRide(at: startedAt.addingTimeInterval(45)).transition,
            .rideContinued
        )
        XCTAssertEqual(controller.state, .riding)
    }

    func testAutomaticEndCancelsOwnedRideWork() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let controller = RideSessionController(
            clock: FixedRideClock(now: startedAt),
            scheduler: RecordingRideSessionScheduler(),
            lifecycle: RideSessionLifecycle(inactivityInterval: 30, confirmationGracePeriod: 30)
        )
        _ = controller.start(wantsLocationInput: true) { _ in }

        let prompt = controller.evaluate(at: startedAt.addingTimeInterval(30))
        XCTAssertEqual(prompt.transition, .inactivityPrompt(deadline: startedAt.addingTimeInterval(60)))
        XCTAssertEqual(prompt.cancellationIntent, .inactivityPrompted)
        let automaticEnd = controller.evaluate(at: startedAt.addingTimeInterval(60))
        XCTAssertEqual(automaticEnd.transition, .automaticEnd)

        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(automaticEnd.cancellationIntent, .rideEnded(wasActive: true))
    }

    func testAutomaticEndReportsActiveSessionWithoutLocationInput() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let controller = RideSessionController(
            clock: FixedRideClock(now: startedAt),
            scheduler: RecordingRideSessionScheduler(),
            lifecycle: RideSessionLifecycle(inactivityInterval: 30, confirmationGracePeriod: 30)
        )
        _ = controller.start(wantsLocationInput: false) { _ in }

        _ = controller.evaluate(at: startedAt.addingTimeInterval(30))
        let automaticEnd = controller.evaluate(at: startedAt.addingTimeInterval(60))

        XCTAssertEqual(automaticEnd.transition, .automaticEnd)
        XCTAssertEqual(automaticEnd.cancellationIntent, .rideEnded(wasActive: true))
        XCTAssertEqual(automaticEnd.effects, [.cancelRideWork(.rideEnded(wasActive: true))])
    }

    func testPlaceResolutionIdentityIsOwnedAndSupersededByController() {
        let controller = RideSessionController(scheduler: RecordingRideSessionScheduler())
        _ = controller.start(wantsLocationInput: true) { _ in }

        let first = controller.beginPlaceResolution()
        let second = controller.beginPlaceResolution()

        XCTAssertNil(first.supersededRequestID)
        XCTAssertEqual(second.supersededRequestID, first.request.requestGeneration)
        XCTAssertFalse(controller.acceptsPlaceResolution(first.request))
        XCTAssertTrue(controller.acceptsPlaceResolution(second.request))
        XCTAssertTrue(controller.finishPlaceResolution(second.request))
        XCTAssertFalse(controller.acceptsPlaceResolution(second.request))
    }

    func testStaleRequestIsRejectedAfterEndAndRestart() {
        let scheduler = RecordingRideSessionScheduler()
        let controller = RideSessionController(scheduler: scheduler)
        _ = controller.start(wantsLocationInput: true) { _ in }
        let staleRequest = controller.beginPlaceResolution().request

        XCTAssertTrue(controller.acceptsPlaceResolution(staleRequest))

        _ = controller.end()
        _ = controller.start(wantsLocationInput: true) { _ in }

        XCTAssertFalse(controller.acceptsPlaceResolution(staleRequest))
    }

    private func location(recordedAt: Date, acceptedAt: Date) -> AcceptedRideLocation {
        AcceptedRideLocation(
            latitude: 51,
            longitude: 0,
            horizontalAccuracy: 5,
            recordedAt: recordedAt,
            acceptedAt: acceptedAt
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

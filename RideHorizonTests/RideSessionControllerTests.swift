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
            [RideSessionControllerTransition(transition: .none)]
        )

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

        let transition = controller.accept(location(recordedAt: startedAt, acceptedAt: startedAt))

        XCTAssertEqual(transition.transition, .none)
        let prompt = controller.evaluate(at: startedAt.addingTimeInterval(30))
        XCTAssertEqual(prompt.transition, .inactivityPrompt(deadline: startedAt.addingTimeInterval(60)))
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
        let automaticEnd = controller.evaluate(at: startedAt.addingTimeInterval(60))
        XCTAssertEqual(automaticEnd.transition, .automaticEnd)

        XCTAssertEqual(controller.state, .idle)
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
        XCTAssertEqual(automaticEnd.effects, [.cancelRideWork(.rideEnded(wasActive: true))])
    }

    func testPlaceResolutionIdentityIsOwnedAndSupersededByController() {
        let controller = RideSessionController(scheduler: RecordingRideSessionScheduler())
        _ = controller.start(wantsLocationInput: true) { _ in }

        let first = controller.beginPlaceResolution(for: location(
            recordedAt: Date(timeIntervalSince1970: 1_000),
            acceptedAt: Date(timeIntervalSince1970: 1_000)
        ))
        let second = controller.beginPlaceResolution(for: location(
            recordedAt: Date(timeIntervalSince1970: 1_001),
            acceptedAt: Date(timeIntervalSince1970: 1_001)
        ))

        XCTAssertEqual(first.effects, [
            .cancelResolver,
            .recordStart(requestID: first.request.requestGeneration),
            .resolve(first.request)
        ])
        XCTAssertEqual(second.effects.first, .recordCancellation(
            requestID: first.request.requestGeneration,
            reason: .supersededByNewerContext
        ))
        XCTAssertFalse(controller.acceptsPlaceResolution(first.request))
        XCTAssertTrue(controller.acceptsPlaceResolution(second.request))
        XCTAssertEqual(
            controller.completePlaceResolution(second.request, result: .unavailable),
            RidePlaceResolutionCompletion(
                requestID: second.request.requestGeneration,
                result: .unavailable
            )
        )
        XCTAssertFalse(controller.acceptsPlaceResolution(second.request))
    }

    func testStaleRequestIsRejectedAfterEndAndRestart() {
        let scheduler = RecordingRideSessionScheduler()
        let controller = RideSessionController(scheduler: scheduler)
        _ = controller.start(wantsLocationInput: true) { _ in }
        let staleRequest = controller.beginPlaceResolution(for: location(
            recordedAt: Date(timeIntervalSince1970: 1_000),
            acceptedAt: Date(timeIntervalSince1970: 1_000)
        )).request

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

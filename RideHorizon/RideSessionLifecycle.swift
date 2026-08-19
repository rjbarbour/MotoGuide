import Foundation
@preconcurrency import UserNotifications

protocol RideClock {
    var now: Date { get }
}

struct SystemRideClock: RideClock {
    var now: Date { Date() }
}

@MainActor
protocol RideSessionScheduling: AnyObject {
    func scheduleRepeating(every interval: TimeInterval, _ action: @escaping @MainActor () -> Void)
    func cancel()
}

@MainActor
final class DispatchRideSessionScheduler: RideSessionScheduling {
    private var timer: DispatchSourceTimer?

    func scheduleRepeating(every interval: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler(handler: action)
        self.timer = timer
        timer.resume()
    }

    func cancel() {
        timer?.cancel()
        timer = nil
    }
}

/// Framework-independent location input accepted by the ride use case.
struct AcceptedRideLocation: Equatable {
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double
    let recordedAt: Date
    let acceptedAt: Date

}

protocol RideDistanceMeasuring {
    func distance(from: AcceptedRideLocation, to: AcceptedRideLocation) -> Double
}

struct SphericalRideDistanceMeasurer: RideDistanceMeasuring {
    func distance(from other: AcceptedRideLocation, to location: AcceptedRideLocation) -> Double {
        let earthRadiusMetres = 6_371_000.0
        let latitudeDelta = (location.latitude - other.latitude) * .pi / 180
        let longitudeDelta = (location.longitude - other.longitude) * .pi / 180
        let firstLatitude = other.latitude * .pi / 180
        let secondLatitude = location.latitude * .pi / 180
        let haversine = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(firstLatitude) * cos(secondLatitude)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        return earthRadiusMetres * 2 * atan2(sqrt(haversine), sqrt(1 - haversine))
    }
}

struct RideSessionStart: Equatable {
    let sessionID: UUID
    let generation: UUID
    let startedAt: Date
    let effects: [RideSessionEffect]
}

struct RideSessionEnd: Equatable {
    let wasActive: Bool
    let invalidatedGeneration: UUID
    let cancellationIntent: RideSessionCancellationIntent
    let effects: [RideSessionEffect]
}

struct RideSessionControllerTransition: Equatable {
    let transition: RideSessionTransition
    let cancellationIntent: RideSessionCancellationIntent?
    let effects: [RideSessionEffect]

    init(
        transition: RideSessionTransition,
        cancellationIntent: RideSessionCancellationIntent?,
        effects: [RideSessionEffect] = []
    ) {
        self.transition = transition
        self.cancellationIntent = cancellationIntent
        self.effects = effects
    }
}

enum RideSessionEffect: Equatable {
    case requestInactivityAuthorization
    case refreshLocationInput
    case cancelRideWork(RideSessionCancellationIntent)
    case showInactivityPrompt(deadline: Date)
    case cancelInactivityPrompt
}

struct RidePlaceResolutionRequest: Equatable {
    let rideGeneration: UUID
    let requestGeneration: UUID
}

struct RidePlaceResolutionStart: Equatable {
    let request: RidePlaceResolutionRequest
    let supersededRequestID: UUID?
}

enum RideSessionState: Equatable {
    case idle
    case riding
    case awaitingConfirmation(deadline: Date)

    var isActive: Bool {
        self != .idle
    }

    var riderLabel: String {
        switch self {
        case .idle:
            return "Ride stopped"
        case .riding:
            return "Ride active"
        case .awaitingConfirmation:
            return "Still riding?"
        }
    }
}

enum RideSessionTransition: Equatable {
    case none
    case inactivityPrompt(deadline: Date)
    case rideContinued
    case movementResumed
    case automaticEnd
}

struct RideSessionLifecycle {
    private let inactivityInterval: TimeInterval
    private let confirmationGracePeriod: TimeInterval
    private let distanceMeasurer: RideDistanceMeasuring
    private(set) var state: RideSessionState = .idle
    private var lastConfirmedMovementAt: Date?
    private var movementAnchor: AcceptedRideLocation?

    init(
        inactivityInterval: TimeInterval = 600,
        confirmationGracePeriod: TimeInterval = 120,
        distanceMeasurer: RideDistanceMeasuring = SphericalRideDistanceMeasurer()
    ) {
        self.inactivityInterval = inactivityInterval
        self.confirmationGracePeriod = confirmationGracePeriod
        self.distanceMeasurer = distanceMeasurer
    }

    mutating func start(at date: Date) {
        state = .riding
        lastConfirmedMovementAt = date
        movementAnchor = nil
    }

    mutating func end() {
        state = .idle
        lastConfirmedMovementAt = nil
        movementAnchor = nil
    }

    @discardableResult
    mutating func continueRide(at date: Date) -> Bool {
        guard case .awaitingConfirmation(let deadline) = state else { return false }
        guard date < deadline else {
            end()
            return false
        }
        state = .riding
        lastConfirmedMovementAt = date
        movementAnchor = nil
        return true
    }

    @discardableResult
    mutating func observe(_ location: AcceptedRideLocation) -> RideSessionTransition {
        let date = location.acceptedAt
        guard state != .idle else { return .none }

        if case .awaitingConfirmation(let deadline) = state, date >= deadline {
            end()
            return .automaticEnd
        }

        let age = date.timeIntervalSince(location.recordedAt)
        guard age >= 0,
              age <= 15,
              location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 30 else {
            return advanceTime(to: date)
        }

        guard let movementAnchor else {
            self.movementAnchor = location
            return advanceTime(to: date)
        }

        let confidenceAdjustedDistance = distanceMeasurer.distance(from: movementAnchor, to: location)
            - movementAnchor.horizontalAccuracy
            - location.horizontalAccuracy

        guard confidenceAdjustedDistance >= 50 else {
            return advanceTime(to: date)
        }

        self.movementAnchor = location
        lastConfirmedMovementAt = date
        if case .awaitingConfirmation = state {
            state = .riding
            return .movementResumed
        }
        return .none
    }

    mutating func advanceTime(to date: Date) -> RideSessionTransition {
        if case .awaitingConfirmation(let deadline) = state {
            guard date >= deadline else { return .none }
            end()
            return .automaticEnd
        }

        guard case .riding = state,
              let lastConfirmedMovementAt,
              date.timeIntervalSince(lastConfirmedMovementAt) >= inactivityInterval else {
            return .none
        }

        let deadline = date.addingTimeInterval(confirmationGracePeriod)
        state = .awaitingConfirmation(deadline: deadline)
        return .inactivityPrompt(deadline: deadline)
    }
}

/// Owns ride use-case state and sequencing. Platform adapters execute the concrete
/// Core Location, geocoder, notification and audio cleanup requested by its results.
@MainActor
final class RideSessionController {
    private let clock: RideClock
    private let scheduler: RideSessionScheduling
    private var lifecycle: RideSessionLifecycle
    private var placeResolutionGeneration = UUID()
    private(set) var activePlaceResolutionID: UUID?

    private(set) var sessionID: UUID?
    private(set) var generation = UUID()
    private(set) var startedAt: Date?
    private(set) var wantsLocationInput = false

    var state: RideSessionState { lifecycle.state }

    init(
        clock: RideClock = SystemRideClock(),
        scheduler: RideSessionScheduling? = nil,
        lifecycle: RideSessionLifecycle = RideSessionLifecycle()
    ) {
        self.clock = clock
        self.scheduler = scheduler ?? DispatchRideSessionScheduler()
        self.lifecycle = lifecycle
    }

    func start(
        at date: Date? = nil,
        wantsLocationInput: Bool,
        lifecycle replacement: RideSessionLifecycle? = nil,
        onScheduledEvaluation: @escaping @MainActor (RideSessionControllerTransition) -> Void
    ) -> RideSessionStart? {
        guard state == .idle else { return nil }
        if let replacement { lifecycle = replacement }
        let startDate = date ?? clock.now
        generation = UUID()
        sessionID = UUID()
        startedAt = startDate
        self.wantsLocationInput = wantsLocationInput
        lifecycle.start(at: startDate)
        placeResolutionGeneration = UUID()
        activePlaceResolutionID = nil
        scheduler.scheduleRepeating(every: 15) { [weak self] in
            guard let self else { return }
            onScheduledEvaluation(self.evaluate())
        }
        var effects: [RideSessionEffect] = [.requestInactivityAuthorization]
        if wantsLocationInput { effects.append(.refreshLocationInput) }
        return RideSessionStart(
            sessionID: sessionID!,
            generation: generation,
            startedAt: startDate,
            effects: effects
        )
    }

    func accept(_ sample: AcceptedRideLocation) -> RideSessionControllerTransition {
        guard state.isActive else {
            return RideSessionControllerTransition(transition: .none, cancellationIntent: nil)
        }
        return process(lifecycle.observe(sample))
    }

    func evaluate(at date: Date? = nil) -> RideSessionControllerTransition {
        process(lifecycle.advanceTime(to: date ?? clock.now))
    }

    func continueRide(at date: Date? = nil) -> RideSessionControllerTransition {
        let wasActive = sessionID != nil
        if lifecycle.continueRide(at: date ?? clock.now) {
            return RideSessionControllerTransition(
                transition: .rideContinued,
                cancellationIntent: nil,
                effects: [.cancelInactivityPrompt]
            )
        }
        guard wasActive, state == .idle else {
            return RideSessionControllerTransition(transition: .none, cancellationIntent: nil)
        }
        return finishAutomaticEnd()
    }

    func end() -> RideSessionEnd {
        let wasActive = wantsLocationInput || state.isActive
        generation = UUID()
        lifecycle.end()
        wantsLocationInput = false
        scheduler.cancel()
        sessionID = nil
        startedAt = nil
        return RideSessionEnd(
            wasActive: wasActive,
            invalidatedGeneration: generation,
            cancellationIntent: .rideEnded(wasActive: wasActive),
            effects: [.cancelRideWork(.rideEnded(wasActive: wasActive))]
        )
    }

    func beginPlaceResolution() -> RidePlaceResolutionStart {
        let supersededRequestID = activePlaceResolutionID
        placeResolutionGeneration = UUID()
        activePlaceResolutionID = placeResolutionGeneration
        return RidePlaceResolutionStart(
            request: RidePlaceResolutionRequest(
                rideGeneration: generation,
                requestGeneration: placeResolutionGeneration
            ),
            supersededRequestID: supersededRequestID
        )
    }

    func acceptsPlaceResolution(_ request: RidePlaceResolutionRequest) -> Bool {
        state == .riding
            && generation == request.rideGeneration
            && activePlaceResolutionID == request.requestGeneration
            && placeResolutionGeneration == request.requestGeneration
    }

    @discardableResult
    func finishPlaceResolution(_ request: RidePlaceResolutionRequest) -> Bool {
        guard acceptsPlaceResolution(request) else { return false }
        activePlaceResolutionID = nil
        return true
    }

    func cancelPlaceResolution() -> UUID? {
        let cancelledRequestID = activePlaceResolutionID
        activePlaceResolutionID = nil
        placeResolutionGeneration = UUID()
        return cancelledRequestID
    }

    private func process(_ transition: RideSessionTransition) -> RideSessionControllerTransition {
        let cancellationIntent: RideSessionCancellationIntent?
        switch transition {
        case .inactivityPrompt:
            cancellationIntent = .inactivityPrompted
        case .automaticEnd:
            return finishAutomaticEnd()
        case .none, .rideContinued, .movementResumed:
            cancellationIntent = nil
        }
        let effects: [RideSessionEffect]
        switch transition {
        case .inactivityPrompt(let deadline):
            effects = [
                .cancelRideWork(.inactivityPrompted),
                .showInactivityPrompt(deadline: deadline)
            ]
        case .rideContinued, .movementResumed:
            effects = [.cancelInactivityPrompt]
        case .none, .automaticEnd:
            effects = []
        }
        return RideSessionControllerTransition(
            transition: transition,
            cancellationIntent: cancellationIntent,
            effects: effects
        )
    }

    private func finishAutomaticEnd() -> RideSessionControllerTransition {
        let wasActive = sessionID != nil
        generation = UUID()
        wantsLocationInput = false
        scheduler.cancel()
        sessionID = nil
        startedAt = nil
        let intent = RideSessionCancellationIntent.rideEnded(wasActive: wasActive)
        return RideSessionControllerTransition(
            transition: .automaticEnd,
            cancellationIntent: intent,
            effects: [.cancelRideWork(intent)]
        )
    }
}

enum RideSessionCancellationIntent: Equatable {
    case inactivityPrompted
    case rideEnded(wasActive: Bool)
}

@MainActor
protocol RideInactivityNotifying: AnyObject {
    func requestAuthorizationIfNeeded()
    func showInactivityPrompt(deadline: Date)
    func cancelInactivityPrompt()
}

@MainActor
final class UserNotificationRideInactivityNotifier: RideInactivityNotifying {
    private static let requestIdentifier = "ridehorizon.ride-session.inactivity"
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { [center] settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert]) { _, _ in }
        }
    }

    func showInactivityPrompt(deadline: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Still riding?"
        content.body = "RideHorizon will end this ride soon. Open the app while stopped to continue."

        let request = UNNotificationRequest(
            identifier: Self.requestIdentifier,
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func cancelInactivityPrompt() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.requestIdentifier])
    }
}

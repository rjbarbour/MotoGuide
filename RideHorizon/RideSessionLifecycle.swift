import Foundation
import CoreLocation
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

/// Platform input owned by the Core Location adapter. The ride controller consumes
/// accepted samples without taking responsibility for CLLocationManager callbacks.
struct AcceptedRideLocation {
    let location: CLLocation
    let acceptedAt: Date
}

struct RideSessionStart: Equatable {
    let sessionID: UUID
    let generation: UUID
    let startedAt: Date
}

struct RideSessionEnd: Equatable {
    let wasActive: Bool
    let invalidatedGeneration: UUID
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
    case movementResumed
    case automaticEnd
}

struct RideSessionLifecycle {
    private let inactivityInterval: TimeInterval
    private let confirmationGracePeriod: TimeInterval
    private(set) var state: RideSessionState = .idle
    private var lastConfirmedMovementAt: Date?
    private var movementAnchor: CLLocation?

    init(
        inactivityInterval: TimeInterval = 600,
        confirmationGracePeriod: TimeInterval = 120
    ) {
        self.inactivityInterval = inactivityInterval
        self.confirmationGracePeriod = confirmationGracePeriod
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
    mutating func observe(_ location: CLLocation, at date: Date) -> RideSessionTransition {
        guard state != .idle else { return .none }

        if case .awaitingConfirmation(let deadline) = state, date >= deadline {
            end()
            return .automaticEnd
        }

        let age = date.timeIntervalSince(location.timestamp)
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

        let confidenceAdjustedDistance = location.distance(from: movementAnchor)
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

    private(set) var sessionID: UUID?
    private(set) var generation = UUID()
    private(set) var startedAt: Date?
    private(set) var wantsLocationInput = false

    var state: RideSessionState { lifecycle.state }

    init(
        clock: RideClock = SystemRideClock(),
        scheduler: RideSessionScheduling = DispatchRideSessionScheduler(),
        lifecycle: RideSessionLifecycle = RideSessionLifecycle()
    ) {
        self.clock = clock
        self.scheduler = scheduler
        self.lifecycle = lifecycle
    }

    func start(
        at date: Date? = nil,
        wantsLocationInput: Bool,
        lifecycle replacement: RideSessionLifecycle? = nil,
        onScheduledEvaluation: @escaping @MainActor (RideSessionTransition) -> Void
    ) -> RideSessionStart? {
        guard state == .idle else { return nil }
        if let replacement { lifecycle = replacement }
        let startDate = date ?? clock.now
        generation = UUID()
        sessionID = UUID()
        startedAt = startDate
        self.wantsLocationInput = wantsLocationInput
        lifecycle.start(at: startDate)
        scheduler.scheduleRepeating(every: 15) { [weak self] in
            guard let self else { return }
            onScheduledEvaluation(self.evaluate())
        }
        return RideSessionStart(sessionID: sessionID!, generation: generation, startedAt: startDate)
    }

    func accept(_ sample: AcceptedRideLocation) -> RideSessionTransition {
        guard state.isActive else { return .none }
        return lifecycle.observe(sample.location, at: sample.acceptedAt)
    }

    func evaluate(at date: Date? = nil) -> RideSessionTransition {
        lifecycle.advanceTime(to: date ?? clock.now)
    }

    func continueRide(at date: Date? = nil) -> Bool {
        lifecycle.continueRide(at: date ?? clock.now)
    }

    func end() -> RideSessionEnd {
        let wasActive = wantsLocationInput || state.isActive
        generation = UUID()
        lifecycle.end()
        wantsLocationInput = false
        scheduler.cancel()
        sessionID = nil
        startedAt = nil
        return RideSessionEnd(wasActive: wasActive, invalidatedGeneration: generation)
    }

    func accepts(rideGeneration: UUID, requestGeneration: UUID, currentRequestGeneration: UUID) -> Bool {
        state == .riding
            && generation == rideGeneration
            && currentRequestGeneration == requestGeneration
    }
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

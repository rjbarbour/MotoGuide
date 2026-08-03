import Foundation
import CoreLocation
@preconcurrency import UserNotifications

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
    private(set) var state: RideSessionState = .idle
    private var lastConfirmedMovementAt: Date?
    private var movementAnchor: CLLocation?

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
              date.timeIntervalSince(lastConfirmedMovementAt) >= 600 else {
            return .none
        }

        let deadline = date.addingTimeInterval(120)
        state = .awaitingConfirmation(deadline: deadline)
        return .inactivityPrompt(deadline: deadline)
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

import ActivityKit
import Foundation

struct RideHorizonActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let placeName: String
        let context: String
    }

    let rideID: UUID
}

@MainActor
protocol RideLiveActivityManaging: AnyObject {
    func endOrphanedActivities()
    func startRide(id: UUID)
    func update(placeName: String, context: String)
    func endRide()
}

@MainActor
final class DisabledRideLiveActivityManager: RideLiveActivityManaging {
    func endOrphanedActivities() {}
    func startRide(id: UUID) {}
    func update(placeName: String, context: String) {}
    func endRide() {}
}

@MainActor
final class SystemRideLiveActivityManager: RideLiveActivityManaging {
    private var activity: Activity<RideHorizonActivityAttributes>?
    private var lastState: RideHorizonActivityAttributes.ContentState?

    func endOrphanedActivities() {
        let orphanedActivities = Activity<RideHorizonActivityAttributes>.activities
        guard !orphanedActivities.isEmpty else { return }

        Task {
            for activity in orphanedActivities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    func startRide(id: UUID) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = RideHorizonActivityAttributes.ContentState(
            placeName: "Locating…",
            context: "Ride in progress"
        )
        lastState = state

        if let existing = Activity<RideHorizonActivityAttributes>.activities.first {
            activity = existing
            updateActivity(existing, state: state)
            return
        }

        activity = try? Activity.request(
            attributes: RideHorizonActivityAttributes(rideID: id),
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
    }

    func update(placeName: String, context: String) {
        let state = RideHorizonActivityAttributes.ContentState(
            placeName: placeName,
            context: context
        )
        guard state != lastState, let activity else { return }
        lastState = state
        updateActivity(activity, state: state)
    }

    func endRide() {
        guard let activity else { return }
        self.activity = nil
        lastState = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func updateActivity(
        _ activity: Activity<RideHorizonActivityAttributes>,
        state: RideHorizonActivityAttributes.ContentState
    ) {
        let alert = AlertConfiguration(
            title: "RideHorizon",
            body: LocalizedStringResource(stringLiteral: state.placeName),
            sound: .named("RideHorizonSilent.caf")
        )
        Task {
            await activity.update(
                ActivityContent(state: state, staleDate: nil),
                alertConfiguration: alert
            )
        }
    }
}

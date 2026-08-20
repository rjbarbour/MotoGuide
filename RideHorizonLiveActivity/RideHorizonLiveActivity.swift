import ActivityKit
import SwiftUI
import WidgetKit

@main
struct RideHorizonLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        RideHorizonLiveActivity()
    }
}

struct RideHorizonLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideHorizonActivityAttributes.self) { context in
            HStack(spacing: 10) {
                Image(systemName: "location.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.placeName)
                        .font(.headline)
                        .lineLimit(1)
                    if !context.state.context.isEmpty {
                        Text(context.state.context)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.9))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text(context.state.placeName)
                            .font(.headline)
                            .lineLimit(1)
                        if !context.state.context.isEmpty {
                            Text(context.state.context)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "location.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                Text(context.state.placeName)
                    .font(.caption2)
                    .lineLimit(1)
            } minimal: {
                Image(systemName: "location.fill")
                    .foregroundStyle(.orange)
            }
            .keylineTint(.orange)
        }
    }
}

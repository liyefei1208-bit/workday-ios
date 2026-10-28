import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity: shows in Notification Center and on the Lock Screen only.
struct WorkdayLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkdayActivityAttributes.self) { context in
            // Notification Center / Lock Screen presentation.
            WorkdayCard(
                state: context.state,
                workRangeLabel: context.attributes.workRangeLabel
            )
            .padding(14)
            .activityBackgroundTint(Color.black.opacity(0.55))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { _ in
            // The Dynamic Island is deliberately left empty: this activity is
            // meant for Notification Center and the Lock Screen, not the island.
            //
            // ActivityConfiguration requires the `dynamicIsland` parameter and
            // ActivityKit has no opt-out flag, so every region returns
            // EmptyView and nothing is drawn in the compact, minimal, or
            // expanded states. Note the system still allocates the island while
            // an activity is active, so the plain pill is a little wider than
            // it is with no activity running — that width is not content-driven
            // and cannot be reclaimed from here.
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { EmptyView() }
                DynamicIslandExpandedRegion(.trailing) { EmptyView() }
                DynamicIslandExpandedRegion(.bottom) { EmptyView() }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                EmptyView()
            } minimal: {
                EmptyView()
            }
        }
    }
}

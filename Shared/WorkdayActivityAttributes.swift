import ActivityKit
import Foundation

/// Live Activity payload. Shared by the app (which starts and updates the
/// activity) and the widget extension (which renders it).
struct WorkdayActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var overallProgress: Double
        var morningProgress: Double
        var afternoonProgress: Double
        var percentOverall: Int
        var percentMorning: Int
        var percentAfternoon: Int
        var phase: DayPhase
        var detailText: String
        var trailingText: String
        var morningRange: String
        var afternoonRange: String
        /// End of the workday, used for the auto-updating countdown.
        var workEnd: Date
        var isWorkday: Bool

        init(snapshot: DaySnapshot) {
            overallProgress = snapshot.overallProgress
            morningProgress = snapshot.morningProgress
            afternoonProgress = snapshot.afternoonProgress
            percentOverall = snapshot.percentOverall
            percentMorning = snapshot.percentMorning
            percentAfternoon = snapshot.percentAfternoon
            phase = snapshot.phase
            detailText = snapshot.detailText
            trailingText = snapshot.trailingText
            morningRange = snapshot.morningRangeLabel
            afternoonRange = snapshot.afternoonRangeLabel
            workEnd = TimeFormat.date(
                minuteOfDay: snapshot.schedule.workEnd,
                on: snapshot.now
            )
            isWorkday = snapshot.isWorkday
        }
    }

    /// Static for the lifetime of the activity.
    var workRangeLabel: String
}

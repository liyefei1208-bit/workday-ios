import SwiftUI

/// The card shown in Notification Center / on the Lock Screen for the Live
/// Activity, and reused by the in-app home screen.
struct WorkdayCard: View {
    var state: WorkdayActivityAttributes.ContentState
    var workRangeLabel: String
    /// Live Activities render on a dark system background.
    var onDark: Bool = true
    var ringDiameter: CGFloat = 78

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if state.isWorkday {
                HStack(alignment: .center, spacing: 14) {
                    OverallRing(
                        progress: state.overallProgress,
                        percent: state.percentOverall,
                        tint: Theme.overallTint(state.phase),
                        diameter: ringDiameter,
                        onDark: onDark
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        SegmentRow(
                            icon: "sunrise.fill",
                            title: "上午",
                            range: state.morningRange,
                            progress: state.morningProgress,
                            percent: state.percentMorning,
                            tint: Theme.ringMorning,
                            compact: true,
                            onDark: onDark
                        )
                        SegmentRow(
                            icon: "sun.max.fill",
                            title: "下午",
                            range: state.afternoonRange,
                            progress: state.afternoonProgress,
                            percent: state.percentAfternoon,
                            tint: Theme.ringAfternoon,
                            compact: true,
                            onDark: onDark
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                footer
            } else {
                restContent
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Theme.statusColor(state.phase))
                .frame(width: 6, height: 6)

            Text(state.phase.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(onDark ? .white.opacity(0.9) : .primary)

            Spacer(minLength: 6)

            Text(workRangeLabel)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(onDark ? .white.opacity(0.5) : .secondary)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text(state.detailText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(
                    state.phase == .overtime
                        ? Theme.overtime
                        : (onDark ? .white.opacity(0.5) : .secondary)
                )

            Spacer(minLength: 4)

            // Inside working hours the system keeps this countdown ticking on
            // its own, so the card stays accurate between app updates.
            //
            // This is wall-clock time until clock-off, which is longer than the
            // remaining *work* time shown elsewhere (that one excludes the
            // lunch and dinner breaks). The label has to say which one it is.
            if state.phase == .working, state.workEnd > .now {
                HStack(spacing: 3) {
                    Text("距下班")
                    Text(timerInterval: Date.now...state.workEnd, countsDown: true)
                        .monospacedDigit()
                }
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(onDark ? .white.opacity(0.42) : .secondary)
            } else if !state.trailingText.isEmpty {
                Text(state.trailingText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        state.phase == .overtime
                            ? Theme.overtime.opacity(0.85)
                            : (onDark ? .white.opacity(0.42) : .secondary)
                    )
            }
        }
    }

    private var restContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("休息日")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(onDark ? .white : .primary)

            Text("今天不用上班，放松一下吧")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(onDark ? .white.opacity(0.5) : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

import SwiftUI
import WidgetKit

// MARK: - Timeline

struct WorkdayEntry: TimelineEntry {
    let date: Date
    let snapshot: DaySnapshot
}

struct WorkdayTimelineProvider: TimelineProvider {
    /// Granularity of the pre-rendered timeline. 2 minutes over an 8-hour day
    /// is ~0.4% per step, which reads as continuous.
    private let step: TimeInterval = 120
    private let horizon: TimeInterval = 3 * 60 * 60

    func placeholder(in context: Context) -> WorkdayEntry {
        entry(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkdayEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkdayEntry>) -> Void) {
        let now = Date()
        var entries: [WorkdayEntry] = []

        // Pre-render a few hours so the widget stays accurate without needing
        // a system reload for every change.
        var cursor = now
        while cursor < now.addingTimeInterval(horizon) {
            entries.append(entry(at: cursor))
            cursor = cursor.addingTimeInterval(step)
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> WorkdayEntry {
        WorkdayEntry(
            date: date,
            snapshot: DaySnapshot(now: date, settings: SharedStore.loadSettings())
        )
    }
}

// MARK: - Views

struct WorkdayWidgetView: View {
    var entry: WorkdayEntry
    /// Renders this family instead of the environment's. `EnvironmentValues`
    /// exposes `widgetFamily` read-only, so the verification harness in
    /// Tools/Verify cannot inject one and passes it here instead.
    var familyOverride: WidgetFamily?

    @Environment(\.widgetFamily) private var environmentFamily

    private var family: WidgetFamily { familyOverride ?? environmentFamily }

    var body: some View {
        switch family {
        case .systemSmall:
            small
        case .systemMedium, .systemLarge:
            medium
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            inline
        default:
            small
        }
    }

    private var snap: DaySnapshot { entry.snapshot }

    // MARK: Home screen

    private var small: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Theme.statusColor(snap.phase))
                    .frame(width: 5, height: 5)
                Text(snap.phase.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            if snap.isWorkday {
                OverallRing(
                    progress: snap.overallProgress,
                    percent: snap.percentOverall,
                    tint: Theme.overallTint(snap.phase),
                    diameter: 78
                )

                Text(snap.detailText)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Spacer(minLength: 0)
                Text("休息日")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text("好好休息")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Theme.statusColor(snap.phase))
                    .frame(width: 5, height: 5)
                Text(snap.isWorkday ? "工作日" : "今日")
                    .font(.system(size: 11, weight: .semibold))
                Text(snap.workRangeLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(AppInfo.watermark)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.primary.opacity(0.22))
            }

            if snap.isWorkday {
                HStack(alignment: .center, spacing: 14) {
                    OverallRing(
                        progress: snap.overallProgress,
                        percent: snap.percentOverall,
                        tint: Theme.overallTint(snap.phase),
                        diameter: 82
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        SegmentRow(
                            icon: "sunrise.fill",
                            title: "上午",
                            range: snap.morningRangeLabel,
                            progress: snap.morningProgress,
                            percent: snap.percentMorning,
                            tint: Theme.ringMorning
                        )
                        SegmentRow(
                            icon: "sun.max.fill",
                            title: "下午",
                            range: snap.afternoonRangeLabel,
                            progress: snap.afternoonProgress,
                            percent: snap.percentAfternoon,
                            tint: Theme.ringAfternoon
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Text(snap.detailText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(snap.phase == .overtime ? Theme.overtime : .secondary)
                    Spacer()
                    Text(snap.trailingText)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("休息日")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                    Text("今天不用上班，放松一下吧")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 2)
                    HStack {
                        Text("下一个工作日")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(
                            TimeFormat.nextWorkdayLabel(
                                from: snap.now,
                                workStart: snap.settings.workStart
                            )
                        )
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: Lock screen

    private var circular: some View {
        Gauge(value: snap.overallProgress) {
            Image(systemName: "briefcase.fill")
        } currentValueLabel: {
            Text("\(snap.percentOverall)")
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .containerBackground(for: .widget) { Color.clear }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(snap.phase.title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
                Text("\(snap.percentOverall)%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

            ProgressView(value: snap.overallProgress)
                .progressViewStyle(.linear)

            Text(snap.isWorkday ? snap.detailText : "好好休息")
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var inline: some View {
        Text(
            snap.isWorkday
                ? "工作日 \(snap.percentOverall)% · \(snap.detailText)"
                : "休息日"
        )
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Widget

struct WorkdayProgressWidget: Widget {
    private let kind = "WorkdayProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorkdayTimelineProvider()) { entry in
            WorkdayWidgetView(entry: entry)
        }
        .configurationDisplayName("工作日进度")
        .description("展示当天的工作进度：整体、上午、下午。")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

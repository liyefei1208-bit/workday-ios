// Verification host: renders the shipping widget and Live Activity views at
// their real sizes, for an arbitrary point in the workday.
//
// This exists because the surfaces it covers cannot be driven from the host:
// adding widgets to the home screen is not scriptable, and the simulator clock
// cannot be moved, so the phase-dependent layouts (lunch, dinner, overtime,
// weekend) would otherwise never be seen.
//
// Two things it does NOT reproduce faithfully:
//
//   * `Text(timerInterval:)` always counts from the real current time, so the
//     card's 距下班 countdown does not match the scenario's clock. The rest of
//     the card does.
//   * iOS renders lock screen accessory widgets with a vibrant monochrome
//     treatment; here they appear in full colour on a dark panel.
//
// Not part of the shipping app — see the WorkdayVerify target in project.yml.

import SwiftUI
import WidgetKit

// MARK: - Scenarios

/// A named point in time. Wednesday 2026-10-28 is a workday; Saturday
/// 2026-10-31 exercises the weekend layout.
struct Scenario {
    let id: String
    let label: String
    let date: Date

    static func make(_ id: String, _ label: String, day: Int, _ hour: Int, _ minute: Int) -> Scenario {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 10
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        let date = Calendar.current.date(from: comps) ?? Date()
        return Scenario(id: id, label: label, date: date)
    }

    static let all: [Scenario] = [
        .make("before-work", "上班前 09:00", day: 28, 9, 0),
        .make("morning", "上午工作 10:45", day: 28, 10, 45),
        .make("lunch", "午休 12:30", day: 28, 12, 30),
        .make("afternoon", "下午工作 15:00", day: 28, 15, 0),
        .make("dinner", "晚餐休息 18:30", day: 28, 18, 30),
        .make("last-stretch", "最后一段 19:15", day: 28, 19, 15),
        .make("overtime", "加班 20:12", day: 28, 20, 12),
        .make("weekend", "周末 11:00", day: 31, 11, 0),
    ]

    static func named(_ id: String) -> Scenario {
        all.first { $0.id == id } ?? all[1]
    }
}

/// Widget point sizes for the 402×874pt screen class (iPhone 16/17 Pro).
enum WidgetSize {
    static let small = CGSize(width: 162, height: 162)
    static let medium = CGSize(width: 344, height: 162)
    static let circular = CGSize(width: 76, height: 76)
    static let rectangular = CGSize(width: 172, height: 76)
}

// MARK: - Chrome

/// Approximates how the system frames a home screen widget, so the screenshots
/// show the same clipping and corner radius the real widget gets.
struct WidgetChrome<Content: View>: View {
    var title: String
    var size: CGSize
    var corner: CGFloat = 24
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)

            content
                .padding(14)
                .frame(width: size.width, height: size.height)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        }
    }
}

/// Lock screen accessory widgets render monochrome over the wallpaper, so they
/// are grouped onto a dark panel rather than the grouped-background used for
/// home screen widgets.
struct AccessoryChrome<Content: View>: View {
    var title: String
    var size: CGSize?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))

            content
                .frame(width: size?.width, height: size?.height)
                .padding(size == nil ? EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10) : EdgeInsets())
                .background(Color.white.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

/// The dark backdrop the accessory widgets sit on.
struct AccessoryPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .environment(\.colorScheme, .dark)
            .foregroundStyle(.white)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.16, green: 0.18, blue: 0.24),
                        Color(red: 0.07, green: 0.08, blue: 0.11),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Pages

struct WidgetGallery: View {
    var scenario: Scenario

    private var entry: WorkdayEntry {
        WorkdayEntry(date: scenario.date, snapshot: DaySnapshot(now: scenario.date, settings: .default))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            HStack(alignment: .top, spacing: 14) {
                WidgetChrome(title: "systemSmall", size: WidgetSize.small) {
                    WorkdayWidgetView(entry: entry, familyOverride: .systemSmall)
                }
                Spacer(minLength: 0)
            }

            WidgetChrome(title: "systemMedium", size: WidgetSize.medium, corner: 26) {
                WorkdayWidgetView(entry: entry, familyOverride: .systemMedium)
            }

            AccessoryPanel {
                VStack(alignment: .leading, spacing: 14) {
                    Text("锁屏组件同款深色背景")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))

                    HStack(alignment: .top, spacing: 14) {
                        AccessoryChrome(title: "circular", size: WidgetSize.circular) {
                            WorkdayWidgetView(entry: entry, familyOverride: .accessoryCircular)
                        }
                        AccessoryChrome(title: "rectangular", size: WidgetSize.rectangular) {
                            WorkdayWidgetView(entry: entry, familyOverride: .accessoryRectangular)
                        }
                        Spacer(minLength: 0)
                    }

                    AccessoryChrome(title: "inline", size: nil) {
                        WorkdayWidgetView(entry: entry, familyOverride: .accessoryInline)
                            .font(.system(size: 13, weight: .medium))
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemGroupedBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(scenario.label)
                .font(.system(size: 19, weight: .bold))
            Text("WidgetKit · \(scenario.id)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

/// The Live Activity's Notification Center / Lock Screen card, over a dark
/// backdrop like the system gives it.
struct ActivityGallery: View {
    var scenario: Scenario

    private var snapshot: DaySnapshot {
        DaySnapshot(now: scenario.date, settings: .default)
    }

    var body: some View {
        let snap = snapshot

        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(scenario.label)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                Text("Live Activity 卡片 · \(scenario.id)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            WorkdayCard(
                state: WorkdayActivityAttributes.ContentState(snapshot: snap),
                workRangeLabel: snap.workRangeLabel
            )
            .padding(14)
            .background(Color.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .frame(width: 366)

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
    }
}

// MARK: - Entry point

struct VerifyRoot: View {
    @State private var scenarioIndex: Int
    @State private var page: String

    init() {
        let args = CommandLine.arguments
        func value(_ flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        let id = value("-scenario") ?? "morning"
        _scenarioIndex = State(
            initialValue: Scenario.all.firstIndex { $0.id == id } ?? 1
        )
        _page = State(initialValue: value("-page") ?? "widgets")
    }

    private var scenario: Scenario { Scenario.all[scenarioIndex] }

    var body: some View {
        Group {
            if page == "activity" {
                ActivityGallery(scenario: scenario)
            } else {
                WidgetGallery(scenario: scenario)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        // Tapping cycles scenarios so the gallery is usable by hand too.
        .onTapGesture {
            scenarioIndex = (scenarioIndex + 1) % Scenario.all.count
        }
    }
}

@main
struct WorkdayVerifyApp: App {
    var body: some Scene {
        WindowGroup { VerifyRoot() }
    }
}

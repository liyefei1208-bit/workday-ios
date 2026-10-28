import ActivityKit
import Combine
import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class WorkdayModel: ObservableObject {
    @Published var settings: WorkdaySettings {
        didSet {
            guard settings != oldValue else { return }
            SharedStore.saveSettings(settings)
            Task { await liveActivity.refresh(snapshot: snapshot) }
        }
    }

    @Published var now: Date = Date()

    let liveActivity = LiveActivityController()

    private var timer: AnyCancellable?

    init() {
        settings = SharedStore.loadSettings()
        liveActivity.adopt()

        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.now = date
            }
    }

    var snapshot: DaySnapshot {
        DaySnapshot(now: now, settings: settings)
    }

    func reset() {
        settings = .default
    }

    /// Called when the app becomes active: push a fresh state and reload widgets.
    func onForeground() async {
        now = Date()
        WidgetCenter.shared.reloadAllTimelines()

        if settings.autoStartLiveActivity, snapshot.isWorkday, !liveActivity.isRunning {
            await liveActivity.start(snapshot: snapshot)
        } else {
            await liveActivity.refresh(snapshot: snapshot)
        }
    }
}

// MARK: - Live Activity

/// Owns the Live Activity lifecycle.
///
/// iOS only lets the app start an activity, and the system retires it after a
/// while (stale after ~8h, removed by ~12h). A workday can be longer than the
/// stale window, so the activity is (re)started whenever the app is opened.
@MainActor
final class LiveActivityController: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    private var activity: Activity<WorkdayActivityAttributes>?

    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Reattaches to an activity that survived an app relaunch.
    func adopt() {
        if let existing = Activity<WorkdayActivityAttributes>.activities.first {
            activity = existing
            isRunning = true
        }
    }

    func start(snapshot: DaySnapshot) async {
        guard isSupported else {
            lastError = "系统未开启「实时活动」，请到 设置 → 工作日 中打开。"
            return
        }
        if activity != nil {
            await refresh(snapshot: snapshot)
            return
        }

        let attributes = WorkdayActivityAttributes(workRangeLabel: snapshot.workRangeLabel)
        let state = WorkdayActivityAttributes.ContentState(snapshot: snapshot)

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: staleDate(for: snapshot)),
                pushType: nil
            )
            isRunning = true
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refresh(snapshot: DaySnapshot) async {
        guard let activity else { return }
        let state = WorkdayActivityAttributes.ContentState(snapshot: snapshot)
        await activity.update(
            ActivityContent(state: state, staleDate: staleDate(for: snapshot))
        )
    }

    func stop() async {
        guard let activity else {
            isRunning = false
            return
        }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
        isRunning = false
    }

    /// Mark the card stale shortly after the next schedule change so iOS dims
    /// it instead of showing a wrong number.
    private func staleDate(for snapshot: DaySnapshot) -> Date {
        let schedule = snapshot.schedule
        let candidates = [
            schedule.workStart,
            schedule.lunchStart,
            schedule.lunchEnd,
            schedule.dinnerStart,
            schedule.dinnerEnd,
            schedule.workEnd,
        ]
        .map { Double($0) }
        .filter { $0 > snapshot.nowMinute }
        .sorted()

        // No further change today (e.g. after work): re-check in 30 minutes.
        let minutesAhead = candidates.first.map { $0 - snapshot.nowMinute } ?? 30
        return snapshot.now.addingTimeInterval(max(60, minutesAhead * 60) + 60)
    }
}

import ActivityKit
import SwiftUI

struct HomeView: View {
    @ObservedObject var model: WorkdayModel
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    progressCard
                    liveActivitySection
                    scheduleSummary
                    watermark
                }
                .padding(18)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(AppInfo.displayName)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("设置")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(model: model)
            }
        }
    }

    private var snap: DaySnapshot { model.snapshot }

    // MARK: Progress

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.statusColor(snap.phase))
                    .frame(width: 7, height: 7)
                Text(snap.phase.title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(TimeFormat.clock(snap.now))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            if snap.isWorkday {
                HStack(alignment: .center, spacing: 20) {
                    OverallRing(
                        progress: snap.overallProgress,
                        percent: snap.percentOverall,
                        tint: Theme.overallTint(snap.phase),
                        diameter: 128
                    )

                    VStack(alignment: .leading, spacing: 16) {
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

                Divider()

                HStack {
                    Text(snap.detailText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(snap.phase == .overtime ? Theme.overtime : .secondary)
                    Spacer()
                    Text(snap.trailingText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("休息日")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                    Text("今天不用上班，放松一下吧")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("下一个工作日")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(
                            TimeFormat.nextWorkdayLabel(
                                from: snap.now,
                                workStart: snap.settings.workStart
                            )
                        )
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .padding(.top, 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: Live Activity

    private var liveActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("消息中心常驻")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if model.liveActivity.isRunning {
                    Text("进行中")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }

            Text("开启后，当天进度会常驻在下拉通知中心和锁屏。iOS 的实时活动最长约 8 小时后变灰，每天打开一次本应用即可重新开始。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if let error = model.liveActivity.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 10) {
                if model.liveActivity.isRunning {
                    Button(role: .destructive) {
                        Task { await model.liveActivity.stop() }
                    } label: {
                        Text("结束")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await model.liveActivity.refresh(snapshot: snap) }
                    } label: {
                        Text("立即刷新")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        Task { await model.liveActivity.start(snapshot: snap) }
                    } label: {
                        Text("开始")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.liveActivity.isSupported)
                }
            }

            Toggle("打开应用时自动开始", isOn: $model.settings.autoStartLiveActivity)
                .font(.system(size: 12))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: Schedule summary

    private var scheduleSummary: some View {
        VStack(spacing: 0) {
            summaryRow("工作时间", snap.workRangeLabel)
            Divider()
            summaryRow(
                "午休",
                model.settings.lunchEnabled
                    ? TimeFormat.range(model.settings.lunchStart, model.settings.lunchEnd)
                    : "未启用"
            )
            Divider()
            summaryRow(
                "晚餐休息",
                model.settings.dinnerEnabled
                    ? TimeFormat.range(model.settings.dinnerStart, model.settings.dinnerEnd)
                    : "未启用"
            )
            Divider()
            summaryRow("每日工时", TimeFormat.duration(snap.totalWork))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }

    private var watermark: some View {
        Text(AppInfo.watermark)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(.primary.opacity(0.24))
            .padding(.top, 2)
            .accessibilityHidden(true)
    }
}

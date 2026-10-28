import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: WorkdayModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("工作时间") {
                    timeRow("上班", $model.settings.workStart)
                    timeRow("下班", $model.settings.workEnd)
                }

                Section("休息时间") {
                    Toggle("启用午休", isOn: $model.settings.lunchEnabled)
                    if model.settings.lunchEnabled {
                        timeRow("开始", $model.settings.lunchStart)
                        timeRow("结束", $model.settings.lunchEnd)
                    }

                    Toggle("启用晚餐休息", isOn: $model.settings.dinnerEnabled)
                    if model.settings.dinnerEnabled {
                        timeRow("开始", $model.settings.dinnerStart)
                        timeRow("结束", $model.settings.dinnerEnd)
                    }
                }

                Section("实时活动") {
                    Toggle("打开应用时自动开始", isOn: $model.settings.autoStartLiveActivity)
                    Text("实时活动显示在下拉通知中心和锁屏。小组件（主屏 / 锁屏）不受时长限制，会自动刷新。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("恢复默认设置") {
                        model.reset()
                    }

                    Text("所有百分比均为「已完成工作占比」。超过下班时间会显示已加班时长，凌晨 0 点自动重置；休息日显示休息状态。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !model.settings.isValid {
                        Label(
                            "时间设置存在冲突，请检查上班 / 下班与休息时间。",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }

                Section("关于") {
                    HStack {
                        Text("应用")
                        Spacer()
                        Text("\(AppInfo.displayName) \(AppInfo.version) (\(AppInfo.build))")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("作者")
                        Spacer()
                        Text(AppInfo.author)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .textSelection(.enabled)
                    }
                    Text(AppInfo.copyright)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func timeRow(_ title: String, _ value: Binding<Int>) -> some View {
        DatePicker(
            title,
            selection: dateBinding(value),
            displayedComponents: .hourAndMinute
        )
    }

    private func dateBinding(_ value: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { TimeFormat.date(minutes: value.wrappedValue) },
            set: { value.wrappedValue = TimeFormat.minutes(from: $0) }
        )
    }
}

import Foundation
import WidgetKit

/// Settings live in an App Group so the widget extension and the Live Activity
/// read the same schedule the app writes.
enum SharedStore {
    static let appGroupID = "group.com.liyefei.workdaywidget"
    private static let settingsKey = "workday.settings.v1"

    /// `UserDefaults(suiteName:)` is nil only when the suite name itself is
    /// rejected; `.standard` keeps that case from crashing. Note that settings
    /// written there are *not* visible to the widget extension, so the App
    /// Group capability must be provisioned for the widgets to track the app.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func loadSettings() -> WorkdaySettings {
        guard let data = defaults.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode(WorkdaySettings.self, from: data)
        else {
            return .default
        }
        return decoded
    }

    static func saveSettings(_ settings: WorkdaySettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: settingsKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - App metadata

enum AppInfo {
    static let author = "yefei.li"
    static let displayName = "工作日"
    static let watermark = "yefei.li"

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String
            ?? "© 2026 \(author)"
    }
}

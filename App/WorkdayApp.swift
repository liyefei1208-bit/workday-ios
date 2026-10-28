import SwiftUI

@main
struct WorkdayApp: App {
    @StateObject private var model = WorkdayModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView(model: model)
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await model.onForeground() }
                }
        }
    }
}

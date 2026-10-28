import SwiftUI
import WidgetKit

@main
struct WorkdayWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkdayProgressWidget()
        WorkdayLiveActivity()
    }
}

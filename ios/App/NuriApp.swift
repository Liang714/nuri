import DesignSystem
import SwiftUI

@main
struct NuriApp: App {
    @State private var appState: AppState

    init() {
        let defaults: UserDefaults
        if ProcessInfo.processInfo.arguments.contains("-uiTestFreshState") {
            let suite = "nuri.uitest"
            UserDefaults().removePersistentDomain(forName: suite)
            defaults = UserDefaults(suiteName: suite) ?? .standard
        } else {
            defaults = .standard
        }
        _appState = State(initialValue: AppState(defaults: defaults))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .tint(.nuriTint)
        }
    }
}

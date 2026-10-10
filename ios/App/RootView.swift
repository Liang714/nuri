import DesignSystem
import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.stage {
            case .complete: MainTabView()
            case .welcome, .consent: OnboardingFlow()
            }
        }
        // Components that can show digits or ads (AdCard, NuriProgressBar) gate themselves on this.
        .environment(\.nuriHideNumbers, appState.hideNumbers)
    }
}

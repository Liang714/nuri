import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.stage {
        case .complete: MainTabView()
        case .welcome, .consent: OnboardingFlow()
        }
    }
}

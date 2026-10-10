import SwiftUI

enum OnboardingRoute: Hashable {
    case email, consent
}

struct OnboardingFlow: View {
    @Environment(AppState.self) private var appState
    @State private var path: [OnboardingRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(
                auth: UnavailableAuthService(),
                onEmail: { path.append(.email) },
                onWithoutAccount: {
                    appState.chooseGuest()
                    path.append(.consent)
                }
            )
            .navigationDestination(for: OnboardingRoute.self) { route in
                switch route {
                case .email:
                    EmailSignInView(onWithoutAccount: {
                        appState.chooseGuest()
                        path.append(.consent)
                    })
                case .consent:
                    ConsentView()
                }
            }
        }
        .onAppear { if appState.stage == .consent && path.isEmpty { path = [.consent] } }
    }
}

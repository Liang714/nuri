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
                onWithoutAccount: showConsent
            )
            .navigationDestination(for: OnboardingRoute.self) { route in
                switch route {
                case .email:
                    EmailSignInView(onWithoutAccount: showConsent)
                case .consent:
                    ConsentView()
                }
            }
        }
        .onAppear { if appState.stage == .consent && path.isEmpty { path = [.consent] } }
    }

    /// Moves to consent from Welcome or email sign-in, never stacking a second consent screen.
    private func showConsent() {
        appState.chooseGuest()
        if path.last != .consent { path.append(.consent) }
    }
}

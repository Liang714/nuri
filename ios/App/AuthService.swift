enum SignInMethod: String, CaseIterable, Sendable {
    case apple, google, email
}

enum AuthAvailability: Equatable, Sendable {
    case available, comingLater
}

/// Account sign-in (Supabase + Sign in with Apple/Google) arrives in the accounts phase.
protocol AuthService: Sendable {
    func availability(for method: SignInMethod) -> AuthAvailability
}

/// This build has no account backend. Nuri works fully without an account.
struct UnavailableAuthService: AuthService {
    func availability(for method: SignInMethod) -> AuthAvailability { .comingLater }
}

import DesignSystem
import SwiftUI

struct WelcomeView: View {
    let auth: any AuthService
    var onEmail: () -> Void
    var onWithoutAccount: () -> Void
    @State private var showAccountsLater = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    WorldView(today: [.vegetables, .grains, .protein, .fruit], resting: [.legumesAndNuts],
                              accessibilityLabel: Text("An illustrated world of food groups"))
                        .frame(width: 196, height: 196)
                        .padding(.top, 40)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(verbatim: "누리").font(.system(size: 40)).foregroundStyle(Color.nuriTint)
                        Text(verbatim: "Nuri").font(.nuriTitle2).foregroundStyle(Color.nuriTint)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "Nuri"))
                    .accessibilityAddTraits(.isHeader)
                    Text("Food and movement, gently")
                        .font(.nuriTitle)
                        .multilineTextAlignment(.center)
                    Text("Add meals, watch your world grow, and get a plan that fits your week. Your data stays yours.")
                        .font(.nuriBody)
                        .foregroundStyle(Color.nuriInkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            }
            VStack(spacing: 10) {
                Button { request(.apple) } label: { Label("Continue with Apple", systemImage: "apple.logo") }
                    .buttonStyle(SolidButtonStyle(fill: .black, text: .white))
                Button { request(.google) } label: { Text("Continue with Google") }
                    .buttonStyle(SolidButtonStyle(fill: .white, text: Color(red: 0.12, green: 0.12, blue: 0.12), outline: Color(red: 0.455, green: 0.467, blue: 0.459)))
                Button(action: onEmail) { Label("Continue with email", systemImage: "envelope") }
                    .buttonStyle(SolidButtonStyle(fill: .nuriFillSecondary, text: .nuriInk))
                Button(action: onWithoutAccount) { Text("Use without an account") }
                    .buttonStyle(NuriTextButtonStyle())
                Text("For adults 18 and over.")
                    .font(.nuriFootnote)
                    .foregroundStyle(Color.nuriInkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .background(Color.nuriGround.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .alert(Text("Account sign-in arrives in a later build"), isPresented: $showAccountsLater) {
            Button("Use without an account", action: onWithoutAccount)
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can use Nuri without an account now and add one later.")
        }
    }

    private func request(_ method: SignInMethod) {
        switch auth.availability(for: method) {
        case .comingLater: showAccountsLater = true
        case .available: break // accounts phase wires real sign-in here
        }
    }
}

/// Full-width 52 pt buttons for the sign-in choices (Apple black, Google white with outline).
private struct SolidButtonStyle: ButtonStyle {
    let fill: Color
    let text: Color
    var outline: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nuriHeadline)
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, minHeight: NuriMetrics.buttonHeight)
            .background(fill.opacity(configuration.isPressed ? 0.85 : 1),
                        in: RoundedRectangle(cornerRadius: NuriMetrics.radiusButton, style: .continuous))
            .overlay {
                if let outline {
                    RoundedRectangle(cornerRadius: NuriMetrics.radiusButton, style: .continuous).strokeBorder(outline, lineWidth: 1)
                }
            }
    }
}

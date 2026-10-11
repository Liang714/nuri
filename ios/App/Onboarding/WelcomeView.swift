import DesignSystem
import SwiftUI

struct WelcomeView: View {
    let auth: any AuthService
    var onEmail: () -> Void
    var onWithoutAccount: () -> Void
    @State private var showAccountsLater = false
    @Environment(\.locale) private var locale
    /// The 누리 logotype is the one size not taken from a text style (40 pt at the default setting). It scales with Dynamic Type
    /// like the text around it; the accessibility audit flags a capped size as only partly supported.
    @ScaledMetric(relativeTo: .largeTitle) private var logoSize: CGFloat = 40

    /// The wordmark as spoken: the Korean name in a Korean UI, otherwise "Nuri".
    private var logotypeLabel: String { locale.language.languageCode == .korean ? "누리" : "Nuri" }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 18) {
                        WorldView(today: [.vegetables, .grains, .protein, .fruit], resting: [.legumesAndNuts],
                                  accessibilityLabel: Text("An illustrated world of food groups"))
                            .frame(width: 196, height: 196)
                            .padding(.top, 40)
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(verbatim: "누리").font(.system(size: logoSize)).foregroundStyle(Color.nuriTint)
                            Text(verbatim: "Nuri").font(.nuriTitle2).foregroundStyle(Color.nuriTint)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: logotypeLabel))
                        .accessibilityAddTraits(.isHeader)
                        Text("Food and movement, gently")
                            .font(.nuriTitle)
                            .multilineTextAlignment(.center)
                        Text("Add meals, watch your world grow, and get a plan that fits your week. Your data stays yours.")
                            .font(.nuriBody)
                            .foregroundStyle(Color.nuriInkSoft)
                            .multilineTextAlignment(.center)
                    }
                    // The choices sit below the copy and scroll with it, so nothing clips at accessibility text sizes.
                    // At default sizes the spacer keeps them near the bottom edge.
                    Spacer(minLength: 24)
                    VStack(spacing: 10) {
                        Button { request(.apple) } label: { Label("Continue with Apple", systemImage: "apple.logo") }
                            .buttonStyle(SolidButtonStyle(fill: BrandButtonColors.appleFill, text: BrandButtonColors.appleText))
                        Button { request(.google) } label: { Text("Continue with Google") }
                            .buttonStyle(SolidButtonStyle(fill: BrandButtonColors.googleFill, text: BrandButtonColors.googleText,
                                                          outline: BrandButtonColors.googleOutline))
                        Button(action: onEmail) { Label("Continue with email", systemImage: "envelope") }
                            .buttonStyle(SolidButtonStyle(fill: .nuriFillSecondary, text: .nuriInk))
                        Button(action: onWithoutAccount) {
                            Text("Use without an account")
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(NuriTextButtonStyle())
                        .accessibilityIdentifier("welcome.withoutAccount")
                        Text("For adults 18 and over.")
                            .font(.nuriFootnote)
                            .foregroundStyle(Color.nuriInkSoft)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
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

/// Apple and Google brand-button colors; documented exception to NuriPalette per their brand guidelines.
/// Each pair follows the provider's light and dark button themes, so the Apple button never sinks into the dark ground.
private enum BrandButtonColors {
    static let appleFill = Color(ThemedColor(light: 0x000000, dark: 0xFFFFFF))
    static let appleText = Color(ThemedColor(light: 0xFFFFFF, dark: 0x000000))
    static let googleFill = Color(ThemedColor(light: 0xFFFFFF, dark: 0x131314))
    static let googleText = Color(ThemedColor(light: 0x1F1F1F, dark: 0xE3E3E3))
    static let googleOutline = Color(ThemedColor(light: 0x747775, dark: 0x8E918F))
}

/// Full-width buttons for the sign-in choices, at least 52 pt tall; labels wrap and the row grows with Dynamic Type.
private struct SolidButtonStyle: ButtonStyle {
    let fill: Color
    let text: Color
    var outline: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nuriHeadline)
            .foregroundStyle(text)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: NuriMetrics.buttonHeight)
            .background(fill.opacity(configuration.isPressed ? 0.85 : 1),
                        in: RoundedRectangle(cornerRadius: NuriMetrics.radiusButton, style: .continuous))
            .overlay {
                if let outline {
                    RoundedRectangle(cornerRadius: NuriMetrics.radiusButton, style: .continuous).strokeBorder(outline, lineWidth: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: NuriMetrics.radiusButton, style: .continuous))
    }
}

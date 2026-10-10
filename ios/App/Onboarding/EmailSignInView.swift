import DesignSystem
import SwiftUI

struct EmailSignInView: View {
    var onWithoutAccount: () -> Void
    @State private var email = ""
    @State private var showLater = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("We will send a 6-digit code. No password to remember.")
                    .font(.nuriBody)
                    .foregroundStyle(Color.nuriInkSoft)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email").font(.nuriSubheadlineEmphasis)
                    TextField("you@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .frame(minHeight: NuriMetrics.buttonHeight)
                        .background(Color.nuriSurface, in: RoundedRectangle(cornerRadius: NuriMetrics.radiusControl, style: .continuous))
                }
                Button { showLater = true } label: { Text("Send code") }
                    .buttonStyle(NuriPrimaryButtonStyle())
                    .disabled(!EmailValidator.isPlausible(email))
                if showLater {
                    NoticeCard(title: Text("Account sign-in arrives in a later build"),
                               message: Text("Email sign-in arrives in a later build. You can use Nuri without an account now."),
                               actionTitle: Text("Use without an account"),
                               action: onWithoutAccount)
                }
            }
            .padding(.horizontal, NuriMetrics.screenMargin)
            .padding(.top, 8)
        }
        .background(Color.nuriGround.ignoresSafeArea())
        .navigationTitle(Text("Sign in with email"))
        .navigationBarTitleDisplayMode(.large)
    }
}

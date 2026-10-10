import DesignSystem
import SwiftUI

struct YouView: View {
    @Environment(AppState.self) private var appState
    @State private var confirmingStartOver = false

    private var consentGiven: Bool { appState.stage == .complete && appState.consent != nil }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: Binding(get: { appState.hideNumbers }, set: { appState.setHideNumbers($0) })) {
                        Text("Hide numbers")
                    }
                    .accessibilityIdentifier("you.hideNumbers")
                } header: { Text("Display") } footer: {
                    Text("Hides calories, nutrients, grams, minutes and ads everywhere in Nuri.")
                }

                Section {
                    LabeledContent { Text(consentGiven ? LocalizedStringKey("Given") : LocalizedStringKey("Off")) } label: { Text("Health data consent") }
                    LabeledContent { Text(appState.consent?.analyticsOptIn == true ? LocalizedStringKey("On") : LocalizedStringKey("Off")) } label: { Text("Anonymous usage stats") }
                    NavigationLink { DataUseView() } label: { Text("What we store and why") }
                } header: { Text("Privacy") }

                Section {
                    Text("Nuri gives general wellness estimates, not medical advice. Food energy, nutrients and exercise vary by person, preparation and device. For medical or nutrition guidance, talk to a qualified clinician.")
                        .font(.nuriFootnote)
                        .foregroundStyle(Color.nuriInkSoft)
                    LabeledContent { Text(verbatim: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") } label: { Text("Version") }
                } header: { Text("About") }

                Section {
                    Button(role: .destructive) { confirmingStartOver = true } label: { Text("Start over") }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("You"))
            .confirmationDialog(Text("Start over?"), isPresented: $confirmingStartOver, titleVisibility: .visible) {
                Button(role: .destructive) { appState.startOver() } label: { Text("Start over") }
                Button(role: .cancel) {} label: { Text("Cancel") }
            } message: {
                Text("This clears your choices on this device and returns to the welcome screen.")
            }
        }
    }
}

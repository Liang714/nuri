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
                    .listRowBackground(Color.nuriSurface)
                } header: { Text("Display") } footer: {
                    Text("Hides calories, nutrients, grams, minutes and ads everywhere in Nuri.")
                }

                Section {
                    LabeledContent { Text(consentGiven ? LocalizedStringKey("Given") : LocalizedStringKey("Off")) } label: { Text("Health data consent") }
                        .listRowBackground(Color.nuriSurface)
                    LabeledContent { Text(appState.consent?.analyticsOptIn == true ? LocalizedStringKey("On") : LocalizedStringKey("Off")) } label: { Text("Anonymous usage stats") }
                        .listRowBackground(Color.nuriSurface)
                    NavigationLink { DataUseView() } label: { Text("What we store and why") }
                        .listRowBackground(Color.nuriSurface)
                } header: { Text("Privacy") }

                Section {
                    Text("Nuri gives general wellness estimates, not medical advice. Food energy, nutrients and exercise vary by person, preparation and device. For medical or nutrition guidance, talk to a qualified clinician.")
                        .font(.nuriFootnote)
                        .foregroundStyle(Color.nuriInkSoft)
                        .listRowBackground(Color.nuriSurface)
                    LabeledContent { Text(verbatim: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") } label: { Text("Version") }
                        .listRowBackground(Color.nuriSurface)
                } header: { Text("About") }

                Section {
                    Button(role: .destructive) { confirmingStartOver = true } label: { Text("Start over") }
                        .foregroundStyle(Color.nuriDestructive)
                        .listRowBackground(Color.nuriSurface)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.nuriGround.ignoresSafeArea())
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

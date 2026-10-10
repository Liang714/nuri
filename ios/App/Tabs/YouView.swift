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
                        rowTitle("Hide numbers")
                    }
                    .accessibilityIdentifier("you.hideNumbers")
                    .listRowBackground(Color.nuriSurface)
                } header: { NuriSectionHeader(Text("Display")) } footer: {
                    Text("Hides calories, nutrients, grams, minutes and ads everywhere in Nuri.").nuriSecondaryText()
                }

                Section {
                    LabeledContent {
                        value(Text(consentGiven ? LocalizedStringKey("Given") : LocalizedStringKey("Off")))
                    } label: { rowTitle("Health data consent") }
                        .accessibilityElement(children: .combine)
                        .listRowBackground(Color.nuriSurface)
                    LabeledContent {
                        value(Text(appState.consent?.analyticsOptIn == true ? LocalizedStringKey("On") : LocalizedStringKey("Off")))
                    } label: { rowTitle("Anonymous usage stats") }
                        .accessibilityElement(children: .combine)
                        .listRowBackground(Color.nuriSurface)
                    NavigationLink { DataUseView() } label: { rowTitle("What we store and why") }
                        .listRowBackground(Color.nuriSurface)
                } header: { NuriSectionHeader(Text("Privacy")) }

                Section {
                    Text("Nuri gives general wellness estimates, not medical advice. Food energy, nutrients and exercise vary by person, preparation and device. For medical or nutrition guidance, talk to a qualified clinician.")
                        .nuriSecondaryText()
                        .listRowBackground(Color.nuriSurface)
                    LabeledContent {
                        value(Text(verbatim: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""))
                    } label: { rowTitle("Version") }
                        .accessibilityElement(children: .combine)
                        .listRowBackground(Color.nuriSurface)
                } header: { NuriSectionHeader(Text("About")) }

                Section {
                    Button(role: .destructive) { confirmingStartOver = true } label: { Text("Start over") }
                        .foregroundStyle(Color.nuriDestructive)
                        .listRowBackground(Color.nuriSurface)
                }
            }
            .nuriGroupedList()
            .navigationTitle(Text("You"))
            .confirmationDialog(Text("Start over?"), isPresented: $confirmingStartOver, titleVisibility: .visible) {
                Button(role: .destructive) { appState.startOver() } label: { Text("Start over") }
                Button(role: .cancel) {} label: { Text("Cancel") }
            } message: {
                Text("This clears your choices on this device and returns to the welcome screen.")
            }
        }
    }

    /// Primary row text, in the ink color at the body style.
    private func rowTitle(_ key: LocalizedStringKey) -> some View {
        Text(key).font(.nuriBody).foregroundStyle(Color.nuriInk)
    }

    /// Trailing value of a `LabeledContent` row, in `nuriInkSoft` (the system's gray is under 4.5:1 on white).
    private func value(_ text: Text) -> some View {
        text.font(.nuriBody).foregroundStyle(Color.nuriInkSoft)
    }
}

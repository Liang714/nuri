import DesignSystem
import SwiftUI

struct ConsentView: View {
    @Environment(AppState.self) private var appState
    @State private var adult = false
    @State private var healthData = false
    @State private var analytics = false

    private var ready: Bool { adult && healthData }

    var body: some View {
        List {
            Section {
                Toggle(isOn: $adult) { row("I am 18 or older", "Nuri is made for adults.") }
                    .accessibilityIdentifier("consent.adult")
                Toggle(isOn: $healthData) {
                    row("Store my food and activity data",
                        "Needed to run Nuri. This is health information, kept private and never sold or used to target ads. Export or delete it anytime.")
                }
                .accessibilityIdentifier("consent.healthData")
                NavigationLink { DataUseView() } label: { Text("What we store and why") }
            } header: { Text("Required") }

            Section {
                Toggle(isOn: $analytics) { row("Share anonymous usage stats", "Helps improve Nuri. Never includes foods, notes or health data.") }
                    .accessibilityIdentifier("consent.analytics")
            } header: { Text("Optional") }

            Section {
                Text("Nuri gives general wellness estimates, not medical advice. Food energy, nutrients and exercise vary by person, preparation and device. For medical or nutrition guidance, talk to a qualified clinician.")
                    .font(.nuriFootnote)
                    .foregroundStyle(Color.nuriInkSoft)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("Before you start"))
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button {
                    try? appState.recordConsent(adult: adult, healthData: healthData, analytics: analytics)
                } label: { Text("Continue") }
                .buttonStyle(NuriPrimaryButtonStyle())
                .disabled(!ready)
                .accessibilityIdentifier("consent.continue")
                if !ready {
                    Text("Turn on the two required items to continue.")
                        .font(.nuriFootnote)
                        .foregroundStyle(Color.nuriInkSoft)
                }
            }
            .padding(.horizontal, NuriMetrics.screenMargin)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    private func row(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.nuriBodyEmphasis)
            Text(detail).font(.nuriFootnote).foregroundStyle(Color.nuriInkSoft)
        }
    }
}

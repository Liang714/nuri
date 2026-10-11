import DesignSystem
import SwiftUI

struct ConsentView: View {
    @Environment(AppState.self) private var appState
    @State private var adult = false
    @State private var healthData = false
    @State private var analytics = false
    @State private var couldNotSave = false

    private var ready: Bool { adult && healthData }

    var body: some View {
        List {
            Section {
                Toggle(isOn: $adult) { row(ConsentCopy.adultTitle, ConsentCopy.adultDetail) }
                    .accessibilityIdentifier("consent.adult")
                    .listRowBackground(Color.nuriSurface)
                Toggle(isOn: $healthData) {
                    row(ConsentCopy.healthTitle, ConsentCopy.healthDetail)
                }
                .accessibilityIdentifier("consent.healthData")
                .listRowBackground(Color.nuriSurface)
                NavigationLink { DataUseView() } label: { Text(ConsentCopy.dataUseLink).font(.nuriBody).foregroundStyle(Color.nuriInk) }
                    .listRowBackground(Color.nuriSurface)
            } header: { NuriSectionHeader(Text(ConsentCopy.requiredHeader)) }

            Section {
                Toggle(isOn: $analytics) { row(ConsentCopy.analyticsTitle, ConsentCopy.analyticsDetail) }
                    .accessibilityIdentifier("consent.analytics")
                    .listRowBackground(Color.nuriSurface)
            } header: { NuriSectionHeader(Text(ConsentCopy.optionalHeader)) }

            Section {
                Text(ConsentCopy.disclaimer)
                    .nuriSecondaryText()
                    .listRowBackground(Color.nuriSurface)
            }
        }
        .nuriGroupedList()
        .navigationTitle(Text(ConsentCopy.screenTitle))
        .navigationBarTitleDisplayMode(.large)
        .alert(Text(ConsentCopy.couldNotSaveTitle), isPresented: $couldNotSave) {
            Button(role: .cancel) {} label: { Text(ConsentCopy.ok) }
        } message: {
            Text(ConsentCopy.couldNotSaveMessage)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button {
                    submit()
                } label: { Text(ConsentCopy.continueButton) }
                .buttonStyle(NuriPrimaryButtonStyle())
                .disabled(!ready)
                .accessibilityIdentifier("consent.continue")
                if !ready {
                    Text(ConsentCopy.requiredHint)
                        .nuriSecondaryText()
                }
            }
            .padding(.horizontal, NuriMetrics.screenMargin)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    private func submit() {
        do throws(ConsentError) {
            try appState.recordConsent(adult: adult, healthData: healthData, analytics: analytics)
        } catch {
            // Only a history that could not be written reaches here (the button is off until both required items are on).
            // Consent is not granted then, so say so instead of leaving a button that seems to do nothing.
            couldNotSave = error == .couldNotRecord
        }
    }

    private func row(_ title: LocalizedStringResource, _ detail: LocalizedStringResource) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.nuriBodyEmphasis).foregroundStyle(Color.nuriInk)
            Text(detail).nuriSecondaryText()
        }
    }
}

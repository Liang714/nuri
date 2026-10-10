import DesignSystem
import SwiftUI

struct DataUseView: View {
    var body: some View {
        List {
            item("Foods and meals you add", "To show your day, your world and your history.", symbol: "fork.knife")
            item("Activity you log or import", "To suggest a plan that fits your week.", symbol: "figure.walk")
            item("Your profile", "Age, height and weight, only to estimate your daily guide.", symbol: "person")
            item("Never", "Selling your data, using it to target ads, or sharing it without your permission.", symbol: "hand.raised")
        }
        .nuriGroupedList()
        .navigationTitle(Text("What we store and why"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func item(_ title: LocalizedStringKey, _ detail: LocalizedStringKey, symbol: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.nuriBodyEmphasis).foregroundStyle(Color.nuriInk)
                Text(detail).nuriSecondaryText()
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(Color.nuriTint)
        }
        .listRowBackground(Color.nuriSurface)
    }
}

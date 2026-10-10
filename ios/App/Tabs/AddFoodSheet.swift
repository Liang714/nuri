import DesignSystem
import SwiftUI

struct AddFoodSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Food search is on its way", systemImage: "magnifyingglass")
            } description: {
                Text("Search, barcode and label scanning arrive with the food database.")
            }
            .background(Color.nuriGround.ignoresSafeArea())
            .navigationTitle(Text("Add food"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

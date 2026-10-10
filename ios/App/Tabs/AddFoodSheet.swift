import DesignSystem
import SwiftUI

struct AddFoodSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label {
                    Text("Food search is on its way").foregroundStyle(Color.nuriInk)
                } icon: {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.nuriInkSoft)
                }
            } description: {
                Text("Search, barcode and label scanning arrive with the food database.").foregroundStyle(Color.nuriInkSoft)
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

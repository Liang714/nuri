import DesignSystem
import SwiftUI

struct DiaryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Nothing added yet", systemImage: "book")
            } description: {
                Text("Meals you add appear here, day by day.")
            }
            .background(Color.nuriGround.ignoresSafeArea())
            .navigationTitle(Text("Diary"))
        }
    }
}

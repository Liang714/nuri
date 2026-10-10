import DesignSystem
import SwiftUI

struct DiaryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label {
                    Text("Nothing added yet").foregroundStyle(Color.nuriInk)
                } icon: {
                    Image(systemName: "book").foregroundStyle(Color.nuriInkSoft)
                }
            } description: {
                Text("Meals you add appear here, day by day.").foregroundStyle(Color.nuriInkSoft)
            }
            .background(Color.nuriGround.ignoresSafeArea())
            .navigationTitle(Text("Diary"))
        }
    }
}

import DesignSystem
import SwiftUI

struct PlanView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label {
                    Text("Your plan is on its way").foregroundStyle(Color.nuriInk)
                } icon: {
                    Image(systemName: "figure.walk").foregroundStyle(Color.nuriInkSoft)
                }
            } description: {
                Text("Suggestions for your week arrive once your profile is set up.").foregroundStyle(Color.nuriInkSoft)
            }
            .background(Color.nuriGround.ignoresSafeArea())
            .navigationTitle(Text("Plan"))
        }
    }
}

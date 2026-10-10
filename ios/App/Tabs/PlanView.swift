import DesignSystem
import SwiftUI

struct PlanView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Your plan is on its way", systemImage: "figure.walk")
            } description: {
                Text("Suggestions for your week arrive once your profile is set up.")
            }
            .background(Color.nuriGround.ignoresSafeArea())
            .navigationTitle(Text("Plan"))
        }
    }
}

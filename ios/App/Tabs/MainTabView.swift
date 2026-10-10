import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView().tabItem { Label("My Nuri", systemImage: "globe.asia.australia") }
            DiaryView().tabItem { Label("Diary", systemImage: "book") }
            PlanView().tabItem { Label("Plan", systemImage: "figure.walk") }
            YouView().tabItem { Label("You", systemImage: "person.crop.circle") }
        }
    }
}

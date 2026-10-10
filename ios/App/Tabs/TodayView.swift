import DesignSystem
import SwiftUI

struct TodayView: View {
    @Environment(AppState.self) private var appState
    @State private var addingFood = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.nuriSubheadlineEmphasis)
                        .foregroundStyle(Color.nuriInkSoft)
                    VStack(spacing: 12) {
                        WorldView(today: [], resting: [], accessibilityLabel: Text("Your world today, empty so far."))
                            .frame(width: 188, height: 188)
                        Text("Your world starts with your first meal.")
                            .font(.nuriBodyEmphasis)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    HStack(spacing: 10) {
                        Button { addingFood = true } label: { Label("Add food", systemImage: "plus") }
                            .buttonStyle(NuriPrimaryButtonStyle())
                        Button { addingFood = true } label: {
                            // An icon in a fixed 52 pt tile: the glyph stops growing at xxxLarge so the tile never overflows.
                            Image(systemName: "barcode.viewfinder").dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        }
                        .buttonStyle(NuriSecondaryButtonStyle(minWidth: NuriMetrics.buttonHeight, minHeight: NuriMetrics.buttonHeight))
                        .accessibilityLabel(Text("Scan a barcode"))
                    }
                    NuriCard {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nothing added yet today").font(.nuriHeadline)
                            if !appState.hideNumbers {
                                Text("Your daily guide appears after you set up your profile.")
                                    .font(.nuriSubheadline)
                                    .foregroundStyle(Color.nuriInkSoft)
                                    .accessibilityIdentifier("today.guide")
                            }
                        }
                        .padding(16)
                    }
                }
                .padding(.horizontal, NuriMetrics.screenMargin)
                .padding(.bottom, 24)
            }
            .background(Color.nuriGround.ignoresSafeArea())
            .navigationTitle(Text("My Nuri"))
            .sheet(isPresented: $addingFood) { AddFoodSheet() }
        }
    }
}

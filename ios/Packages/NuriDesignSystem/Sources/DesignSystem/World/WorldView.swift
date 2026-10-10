import SwiftUI
import NuriDomain

/// Nuri's signature: each food group eaten today is a place on a small world.
/// Groups from earlier in the week rest as outlines. Nothing shrinks; there is no count.
public struct WorldView: View {
    private let today: [FoodGroup]
    private let resting: [FoodGroup]
    private let label: Text
    @Environment(\.colorScheme) private var colorScheme

    public init(today: [FoodGroup], resting: [FoodGroup], accessibilityLabel: Text) {
        self.today = today
        self.resting = resting.filter { !today.contains($0) }
        self.label = accessibilityLabel
    }

    public var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack(alignment: .topLeading) {
                Circle().fill(Color(WorldPalette.globe))
                ForEach(FoodGroup.allCases, id: \.self) { group in
                    if today.contains(group) {
                        place(group, side: side, filled: true)
                    } else if resting.contains(group) {
                        place(group, side: side, filled: false)
                    }
                }
            }
            .frame(width: side, height: side)
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.12), radius: 12, y: 8)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private func place(_ group: FoodGroup, side: CGFloat, filled: Bool) -> some View {
        let r = WorldLayout.slot(for: group)
        let w = r.width * side, h = r.height * side
        let shape = UnevenRoundedRectangle(topLeadingRadius: h * 0.55, bottomLeadingRadius: h * 0.45,
                                           bottomTrailingRadius: h * 0.6, topTrailingRadius: h * 0.5, style: .continuous)
        let ring = colorScheme == .dark ? group.ring.dark : group.ring.light
        Group {
            if filled {
                shape.fill(Color(group.fill))
                    .overlay(shape.strokeBorder(Color(ring), lineWidth: 2))
                    .background(shape.stroke(Color(WorldPalette.halo), lineWidth: 3))
            } else {
                shape.fill(Color(group.fill).opacity(0.18))
                    .overlay(shape.strokeBorder(Color(ring), style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
            }
        }
        .frame(width: w, height: h)
        .offset(x: r.minX * side, y: r.minY * side)
    }
}

#Preview("World") {
    WorldView(today: [.vegetables, .grains, .protein, .fruit], resting: [.legumesAndNuts],
              accessibilityLabel: Text(verbatim: "Your world today"))
        .frame(width: 196, height: 196)
        .padding()
}

import SwiftUI

/// Calm, always-blue progress. Over 100% stays the same color: a guide, not a limit.
public struct NuriProgressBar: View {
    private let fraction: Double
    private let label: Text
    private let valueText: Text

    public init(value: Double, total: Double, label: Text, valueText: Text) {
        self.fraction = Self.fraction(value: value, total: total)
        self.label = label
        self.valueText = valueText
    }

    public nonisolated static func fraction(value: Double, total: Double) -> Double {
        guard value.isFinite, total.isFinite, total > 0 else { return 0 }
        return min(1, max(0, value / total))
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.nuriTrack)
                Capsule().fill(Color.nuriProgress).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(valueText)
    }
}

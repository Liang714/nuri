import SwiftUI

/// Calm, always-blue progress. Over 100% stays the same color: a guide, not a limit.
///
/// Gates itself on Hide numbers (`EnvironmentValues.nuriHideNumbers`): the bar has no digits so it stays,
/// but its spoken value (which carries the amounts) is dropped and only the label is read.
public struct NuriProgressBar: View {
    private let fraction: Double
    private let label: Text
    private let valueText: Text
    @Environment(\.nuriHideNumbers) private var hideNumbers

    public init(value: Double, total: Double, label: Text, valueText: Text) {
        self.fraction = Self.fraction(value: value, total: total)
        self.label = label
        self.valueText = valueText
    }

    public nonisolated static func fraction(value: Double, total: Double) -> Double {
        guard value.isFinite, total.isFinite, total > 0 else { return 0 }
        return min(1, max(0, value / total))
    }

    /// The value VoiceOver reads after the label, or nil when none should be spoken.
    static func spokenValue(_ valueText: Text, hideNumbers: Bool) -> Text? {
        hideNumbers ? nil : valueText
    }

    public var body: some View {
        let bar = GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.nuriTrack)
                Capsule().fill(Color.nuriProgress).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        if let value = Self.spokenValue(valueText, hideNumbers: hideNumbers) {
            bar.accessibilityValue(value)
        } else {
            bar
        }
    }
}

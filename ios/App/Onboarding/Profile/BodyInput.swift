import Foundation
import NuriDomain

/// Height and weight as the Body step enters them: the limits, the conversions and the text round trip.
/// The engines work in centimeters and kilograms; every range check happens before a value is converted for display.
enum BodyInput {
    static let heightRangeCm: ClosedRange<Int> = Int(BodyProfile.heightRangeCm.lowerBound)...Int(BodyProfile.heightRangeCm.upperBound)

    static func isValidHeight(cm: Double) -> Bool { BodyProfile.heightRangeCm.contains(cm) }

    /// False for NaN and infinity too (a closed range never contains them).
    static func isValidWeight(kg: Double) -> Bool { BodyProfile.weightRangeKg.contains(kg) }

    /// `cm` inside the valid height range; a value that is not a number becomes the lower bound.
    static func clampedHeightCm(_ cm: Double) -> Double {
        guard cm.isFinite else { return BodyProfile.heightRangeCm.lowerBound }
        return min(max(cm, BodyProfile.heightRangeCm.lowerBound), BodyProfile.heightRangeCm.upperBound)
    }

    // MARK: Imperial height

    /// Whole inches that fall inside the valid height range (40 in is 101.6 cm, 98 in is 248.9 cm).
    static let imperialHeightInches: ClosedRange<Int> = {
        let lower = Int((BodyProfile.heightRangeCm.lowerBound / BodyUnits.centimetersPerInch).rounded(.up))
        let upper = Int((BodyProfile.heightRangeCm.upperBound / BodyUnits.centimetersPerInch).rounded(.down))
        return lower...upper
    }()

    static let feetChoices: ClosedRange<Int> = (imperialHeightInches.lowerBound / 12)...(imperialHeightInches.upperBound / 12)

    /// The inches that can follow `feet`: 4...11 at 3 ft and 0...2 at 8 ft keep the height inside the valid range.
    static func inchChoices(forFeet feet: Int) -> ClosedRange<Int> {
        let lower = max(0, imperialHeightInches.lowerBound - feet * 12)
        let upper = min(11, imperialHeightInches.upperBound - feet * 12)
        return lower <= upper ? lower...upper : 0...0
    }

    /// Feet and inches for a height in centimeters, kept inside `imperialHeightInches`.
    static func feetAndInches(cm: Double) -> (feet: Int, inches: Int) {
        let converted = BodyUnits.feetAndInches(cm: clampedHeightCm(cm))
        let total = min(max(converted.feet * 12 + converted.inches, imperialHeightInches.lowerBound), imperialHeightInches.upperBound)
        return (total / 12, total % 12)
    }

    /// The height for a wheel selection, kept inside `imperialHeightInches` (a feet change can push the inches into range).
    static func heightCm(feet: Int, inches: Int) -> Double {
        let total = min(max(feet * 12 + inches, imperialHeightInches.lowerBound), imperialHeightInches.upperBound)
        return BodyUnits.cm(feet: total / 12, inches: total % 12)
    }

    // MARK: Weight

    /// The smallest and largest whole numbers in `unit` that are still inside 30...350 kg once converted
    /// (67...771 lb), so the range shown never promises a value that is then refused.
    static func weightBounds(in unit: UnitSystem) -> ClosedRange<Int> {
        switch unit {
        case .metric:
            return Int(BodyProfile.weightRangeKg.lowerBound)...Int(BodyProfile.weightRangeKg.upperBound)
        case .imperial:
            let lower = Int(BodyUnits.pounds(kg: BodyProfile.weightRangeKg.lowerBound).rounded(.up))
            let upper = Int(BodyUnits.pounds(kg: BodyProfile.weightRangeKg.upperBound).rounded(.down))
            return lower...upper
        }
    }

    /// The weight as typed: at most one decimal, no grouping, the locale's own decimal separator.
    static func weightText(kg: Double, unit: UnitSystem, locale: Locale) -> String {
        guard kg.isFinite else { return "" }
        let value = unit == .metric ? kg : BodyUnits.pounds(kg: kg)
        return value.formatted(.number.locale(locale).precision(.fractionLength(0...1)).grouping(.never))
    }

    /// Kilograms for the text a person typed in `unit`, or nil when it is not a number. The range is not checked here.
    /// Only digits and one decimal separator are a number: "65 kg" and "6 5" are not, however forgiving the formatter is.
    static func weightKg(from text: String, unit: UnitSystem, locale: Locale) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = Character(locale.decimalSeparator ?? ".")
        let separators = trimmed.filter { $0 == separator }.count
        guard !trimmed.isEmpty,
              separators <= 1,
              trimmed.allSatisfy({ $0 == separator || $0.wholeNumberValue != nil }),
              trimmed.contains(where: { $0.wholeNumberValue != nil }),
              let value = try? Double(trimmed, format: .number.locale(locale)),
              value.isFinite else { return nil }
        return unit == .metric ? value : BodyUnits.kg(pounds: value)
    }
}

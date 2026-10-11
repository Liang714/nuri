import Foundation
import NuriDomain
import Persistence
import Testing
@testable import Nuri

@Suite struct BodyInputTests {
    static let en = Locale(identifier: "en_US")
    static let de = Locale(identifier: "de_DE")

    // MARK: Limits

    @Test func heightLimitsAreTheEnginesLimits() {
        #expect(BodyInput.heightRangeCm == 100...250)
        #expect(BodyInput.isValidHeight(cm: 100))
        #expect(BodyInput.isValidHeight(cm: 250))
        #expect(!BodyInput.isValidHeight(cm: 99.9))
        #expect(!BodyInput.isValidHeight(cm: 250.1))
        #expect(!BodyInput.isValidHeight(cm: .nan))
    }

    @Test func weightLimitsAreTheEnginesLimits() {
        #expect(BodyInput.isValidWeight(kg: 30))
        #expect(BodyInput.isValidWeight(kg: 350))
        #expect(!BodyInput.isValidWeight(kg: 29.9))
        #expect(!BodyInput.isValidWeight(kg: 350.1))
        #expect(!BodyInput.isValidWeight(kg: .nan))
        #expect(!BodyInput.isValidWeight(kg: .infinity))
    }

    @Test func weightBoundsShownNeverPromiseAValueThatIsRefused() {
        #expect(BodyInput.weightBounds(in: .metric) == 30...350)
        let pounds = BodyInput.weightBounds(in: .imperial)
        #expect(pounds == 67...771)
        // Both ends convert to a valid weight, and one step outside either end does not.
        #expect(BodyInput.isValidWeight(kg: BodyUnits.kg(pounds: Double(pounds.lowerBound))))
        #expect(BodyInput.isValidWeight(kg: BodyUnits.kg(pounds: Double(pounds.upperBound))))
        #expect(!BodyInput.isValidWeight(kg: BodyUnits.kg(pounds: Double(pounds.lowerBound - 1))))
        #expect(!BodyInput.isValidWeight(kg: BodyUnits.kg(pounds: Double(pounds.upperBound + 1))))
    }

    // MARK: Imperial height

    @Test func imperialHeightWheelsStayInsideTheValidRange() {
        #expect(BodyInput.imperialHeightInches == 40...98)
        #expect(BodyInput.feetChoices == 3...8)
        #expect(BodyInput.inchChoices(forFeet: 3) == 4...11)
        #expect(BodyInput.inchChoices(forFeet: 5) == 0...11)
        #expect(BodyInput.inchChoices(forFeet: 8) == 0...2)
        for feet in BodyInput.feetChoices {
            for inches in BodyInput.inchChoices(forFeet: feet) {
                #expect(BodyInput.isValidHeight(cm: BodyInput.heightCm(feet: feet, inches: inches)), "\(feet) ft \(inches) in")
            }
        }
    }

    @Test func feetAndInchesRoundTripTheDefaultHeight() {
        let parts = BodyInput.feetAndInches(cm: 170)
        #expect(parts.feet == 5 && parts.inches == 7)
        #expect(abs(BodyInput.heightCm(feet: 5, inches: 10) - 177.8) < 0.001)
    }

    @Test func heightsOutsideTheRangeAreBroughtInsideBeforeConverting() {
        // 100 cm rounds to 3 ft 3 in, which is below the valid range (99.06 cm): the wheel shows 3 ft 4 in.
        var parts = BodyInput.feetAndInches(cm: 100)
        #expect(parts.feet == 3 && parts.inches == 4)
        parts = BodyInput.feetAndInches(cm: 250)
        #expect(parts.feet == 8 && parts.inches == 2)
        parts = BodyInput.feetAndInches(cm: .nan)
        #expect(parts.feet == 3 && parts.inches == 4)
        parts = BodyInput.feetAndInches(cm: -40)
        #expect(parts.feet == 3 && parts.inches == 4)
        parts = BodyInput.feetAndInches(cm: .infinity)
        #expect(parts.feet == 3 && parts.inches == 4)
        // A wheel selection that would leave the range is brought back: 3 ft 0 in becomes 3 ft 4 in; 8 ft 11 in becomes 8 ft 2 in.
        #expect(abs(BodyInput.heightCm(feet: 3, inches: 0) - BodyInput.heightCm(feet: 3, inches: 4)) < 0.001)
        #expect(abs(BodyInput.heightCm(feet: 8, inches: 11) - BodyInput.heightCm(feet: 8, inches: 2)) < 0.001)
    }

    // MARK: Weight text

    @Test func weightTextShowsAtMostOneDecimalWithoutGrouping() {
        #expect(BodyInput.weightText(kg: 65, unit: .metric, locale: Self.en) == "65")
        #expect(BodyInput.weightText(kg: 65.04, unit: .metric, locale: Self.en) == "65")
        #expect(BodyInput.weightText(kg: 65.5, unit: .metric, locale: Self.en) == "65.5")
        #expect(BodyInput.weightText(kg: 65, unit: .imperial, locale: Self.en) == "143.3")
        #expect(BodyInput.weightText(kg: 340, unit: .imperial, locale: Self.en) == "749.6")
        #expect(BodyInput.weightText(kg: 65, unit: .imperial, locale: Self.de) == "143,3")
        #expect(BodyInput.weightText(kg: .nan, unit: .metric, locale: Self.en) == "")
    }

    @Test func typedWeightIsReadInTheUnitBeingEntered() throws {
        #expect(BodyInput.weightKg(from: "65", unit: .metric, locale: Self.en) == 65)
        #expect(BodyInput.weightKg(from: "65.5", unit: .metric, locale: Self.en) == 65.5)
        #expect(BodyInput.weightKg(from: " 65 ", unit: .metric, locale: Self.en) == 65)
        let kg = try #require(BodyInput.weightKg(from: "143.3", unit: .imperial, locale: Self.en))
        #expect(abs(kg - 64.9998) < 0.001)
    }

    @Test func typedWeightUsesTheLocalesDecimalSeparator() {
        #expect(BodyInput.weightKg(from: "65,5", unit: .metric, locale: Self.de) == 65.5)
    }

    @Test(arguments: ["", " ", "abc", "65 kg", "6 5", "NaN", "inf", "-5", "--5", "6.5.5", "."])
    func textThatIsNotANumberGivesNil(text: String) {
        #expect(BodyInput.weightKg(from: text, unit: .metric, locale: Self.en) == nil, "\(text.debugDescription)")
    }

    @Test func aTrailingDecimalSeparatorIsStillANumber() {
        // The decimal pad lets someone type "65." on the way to "65.5": that must not disable Continue for a moment.
        #expect(BodyInput.weightKg(from: "65.", unit: .metric, locale: Self.en) == 65)
    }

    @Test func aNumberOutsideTheRangeIsReadButNotAccepted() throws {
        let tooLight = try #require(BodyInput.weightKg(from: "10", unit: .metric, locale: Self.en))
        #expect(!BodyInput.isValidWeight(kg: tooLight))
        let poundsTooLight = try #require(BodyInput.weightKg(from: "60", unit: .imperial, locale: Self.en))
        #expect(!BodyInput.isValidWeight(kg: poundsTooLight))
        let zero = try #require(BodyInput.weightKg(from: "0", unit: .metric, locale: Self.en))
        #expect(!BodyInput.isValidWeight(kg: zero))
    }

    // MARK: Body step completeness

    @Test func theBodyStepNeedsAValidHeightAndWeight() {
        var draft = ProfileDraft.starting(regionCode: "KR", currentYear: 2026)
        #expect(bodyStepIsComplete(draft: draft, weightEdit: nil, locale: Self.en), "the defaults are valid")
        #expect(!bodyStepIsComplete(draft: draft, weightEdit: "", locale: Self.en))
        #expect(!bodyStepIsComplete(draft: draft, weightEdit: "10", locale: Self.en))
        #expect(bodyStepIsComplete(draft: draft, weightEdit: "70", locale: Self.en))

        draft.unitSystem = .imperial
        #expect(bodyStepIsComplete(draft: draft, weightEdit: "150", locale: Self.en))
        #expect(!bodyStepIsComplete(draft: draft, weightEdit: "60", locale: Self.en), "60 lb is 27 kg")

        draft.heightCm = 90
        #expect(!bodyStepIsComplete(draft: draft, weightEdit: nil, locale: Self.en))
    }
}

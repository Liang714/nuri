import Testing
@testable import NutritionEngine

@Suite struct ServingsTests {
    let options = [
        ServingOption(id: "slice", unit: .slice, label: nil, gramsPerUnit: 32),
        ServingOption(id: "cup", unit: .cup, label: nil, gramsPerUnit: 158),
        ServingOption(id: "pkg", unit: .package, label: "1 pack (210 g)", gramsPerUnit: 210),
    ]

    @Test func massUnitsNeedNoOptions() throws {
        #expect(try ServingConverter.grams(quantity: 150, unit: .gram, options: []) == 150)
        #expect(approx(try ServingConverter.grams(quantity: 2, unit: .ounce, options: []), 56.699))
    }

    @Test func foodSpecificUnitsUseOptions() throws {
        #expect(try ServingConverter.grams(quantity: 2, unit: .slice, options: options) == 64)
        #expect(try ServingConverter.grams(quantity: 0.5, unit: .cup, options: options) == 79)
        #expect(try ServingConverter.grams(quantity: 1, unit: .package, options: options) == 210)
    }

    @Test func volumeWithoutGramWeightIsAnError() {
        #expect(throws: ServingConversionError.missingGramWeight(.milliliter)) {
            try ServingConverter.grams(quantity: 200, unit: .milliliter, options: options)
        }
    }

    @Test func nonPositiveQuantityIsAnError() {
        #expect(throws: ServingConversionError.nonPositiveQuantity) {
            try ServingConverter.grams(quantity: 0, unit: .gram, options: [])
        }
    }

    @Test func convertFromChosenOption() throws {
        let small = ServingOption(id: "small", unit: .piece, label: nil, gramsPerUnit: 40)
        let large = ServingOption(id: "large", unit: .piece, label: nil, gramsPerUnit: 60)
        #expect(try ServingConverter.grams(quantity: 2, option: large) == 120)
        #expect(try ServingConverter.grams(quantity: 2, option: small) == 80)
    }

    @Test func convertFromOptionNonPositiveQuantityIsAnError() {
        let large = ServingOption(id: "large", unit: .piece, label: nil, gramsPerUnit: 60)
        #expect(throws: ServingConversionError.nonPositiveQuantity) {
            try ServingConverter.grams(quantity: 0, option: large)
        }
    }
}

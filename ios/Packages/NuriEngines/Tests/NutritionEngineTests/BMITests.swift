import Testing
@testable import NutritionEngine

func approx(_ a: Double, _ b: Double, tol: Double = 0.01) -> Bool { abs(a - b) <= tol }

@Suite struct BMITests {
    @Test func value() {
        #expect(approx(BMI.value(weightKg: 70, heightCm: 175), 22.857))
    }

    @Test(arguments: [
        (70.0, 175.0, BMICategory.normal, BMICategory.normal),
        (72.0, 170.0, .normal, .overweight),      // 24.9
        (80.0, 170.0, .overweight, .obese),       // 27.7
        (95.0, 170.0, .obese, .obese),            // 32.9
        (50.0, 170.0, .underweight, .underweight) // 17.3
    ])
    func categories(weight: Double, height: Double, who: BMICategory, asian: BMICategory) {
        let bmi = BMI.value(weightKg: weight, heightCm: height)
        #expect(BMI.category(for: bmi, standard: .who) == who)
        #expect(BMI.category(for: bmi, standard: .asianPacific) == asian)
    }

    @Test func boundariesBelongToHigherCategory() {
        #expect(BMI.underweightCutoff == 18.5)
        #expect(BMI.category(for: BMI.underweightCutoff, standard: .asianPacific) == .normal)
        #expect(BMI.category(for: BMI.underweightCutoff.nextDown, standard: .who) == .underweight)
        #expect(BMI.category(for: 18.5, standard: .who) == .normal)
        #expect(BMI.category(for: 25.0, standard: .who) == .overweight)
        #expect(BMI.category(for: 30.0, standard: .who) == .obese)
        #expect(BMI.category(for: 23.0, standard: .asianPacific) == .overweight)
        #expect(BMI.category(for: 25.0, standard: .asianPacific) == .obese)
    }

    @Test func defaultStandardByRegion() {
        #expect(BMIStandard.defaultStandard(forRegion: "KR") == .asianPacific)
        #expect(BMIStandard.defaultStandard(forRegion: "jp") == .asianPacific)
        #expect(BMIStandard.defaultStandard(forRegion: "US") == .who)
        #expect(BMIStandard.defaultStandard(forRegion: nil) == .who)
    }
}

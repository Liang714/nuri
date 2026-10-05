import Testing
@testable import ActivityEngine

@Suite struct EnergyEstimatorTests {
    @Test func metFormula() {
        #expect(approx(EnergyEstimator.kcal(met: 3.5, weightKg: 70, minutes: 30), 122.5))
    }

    @Test func rangeUsesMinus20Plus25() {
        let r = EnergyEstimator.kcalRange(met: 3.5, weightKg: 70, minutes: 30)
        #expect(approx(r.low, 98))
        #expect(approx(r.estimate, 122.5))
        #expect(approx(r.high, 153.125))
    }
}

import Testing
@testable import DesignSystem

@Suite struct ProgressBarTests {
    @Test func fractionClamps() {
        #expect(NuriProgressBar.fraction(value: 1240, total: 2000) == 0.62)
        #expect(NuriProgressBar.fraction(value: 2120, total: 2000) == 1)
        #expect(NuriProgressBar.fraction(value: -5, total: 2000) == 0)
        #expect(NuriProgressBar.fraction(value: 10, total: 0) == 0)
        #expect(NuriProgressBar.fraction(value: .nan, total: 100) == 0)
    }
}

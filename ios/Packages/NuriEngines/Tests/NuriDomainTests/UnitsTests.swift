import Testing
@testable import NuriDomain

@Suite struct UnitsTests {
    @Test func regionDefaults() {
        #expect(UnitSystem.defaultFor(regionCode: "US") == .imperial)
        #expect(UnitSystem.defaultFor(regionCode: "kr") == .metric)
        #expect(UnitSystem.defaultFor(regionCode: nil) == .metric)
    }
    @Test func heightRoundTrip() {
        #expect(abs(BodyUnits.cm(feet: 5, inches: 10) - 177.8) < 0.001)
        #expect(BodyUnits.feetAndInches(cm: 177.8) == (5, 10))
        #expect(BodyUnits.feetAndInches(cm: 182.88) == (6, 0))   // 72 in, no "5 ft 12 in"
    }
    @Test func weightRoundTrip() {
        #expect(abs(BodyUnits.kg(pounds: 150) - 68.0388555) < 0.0001)
        #expect(abs(BodyUnits.pounds(kg: 68.0388555) - 150) < 0.0001)
    }
    @Test func feetAndInchesIsZeroForValuesThatAreNotAHeight() {
        // A stray NaN, infinity, zero or negative height must neither trap nor produce negative feet/inches.
        for cm in [Double.nan, .infinity, -.infinity, 0, -5, -177.8, 1e300] {
            let result = BodyUnits.feetAndInches(cm: cm)
            #expect(result.feet == 0 && result.inches == 0, "cm \(cm) gave \(result)")
        }
    }
}

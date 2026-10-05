import Testing
@testable import NuriDomain

@Suite struct BodyProfileTests {
    let valid = BodyProfile(ageYears: 30, sex: .male, heightCm: 180, weightKg: 80,
                            activityLevel: .moderatelyActive, goal: .maintain)

    @Test func activityFactorsMatchSpec() {
        #expect(ActivityLevel.sedentary.factor == 1.2)
        #expect(ActivityLevel.lightlyActive.factor == 1.375)
        #expect(ActivityLevel.moderatelyActive.factor == 1.55)
        #expect(ActivityLevel.veryActive.factor == 1.725)
        #expect(ActivityLevel.extraActive.factor == 1.9)
    }

    @Test func activityLevelsAreOrdered() {
        #expect(ActivityLevel.sedentary < .moderatelyActive)
        #expect(ActivityLevel.extraActive > .veryActive)
    }

    @Test func validProfilePasses() throws {
        #expect(try valid.validated() == valid)
    }

    @Test func under18IsRejected() {
        var p = valid; p.ageYears = 17
        #expect(throws: ProfileValidationError.ageOutOfRange(17)) { try p.validated() }
    }

    @Test func implausibleHeightAndWeightRejected() {
        var h = valid; h.heightCm = 90
        #expect(throws: ProfileValidationError.heightOutOfRange(90)) { try h.validated() }
        var w = valid; w.weightKg = 20
        #expect(throws: ProfileValidationError.weightOutOfRange(20)) { try w.validated() }
    }
}

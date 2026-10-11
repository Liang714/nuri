import Foundation
import NuriDomain
import NutritionEngine
import Persistence
import Testing
@testable import Nuri

/// The own-number field of the daily guide step and the rule for when Finish is on.
@Suite struct DailyGuideInputTests {
    private static let year = 2026

    // MARK: Reading the field

    @Test func anEmptyFieldOrOneWithoutDigitsIsEmpty() {
        #expect(ManualTargetInput(text: "") == .empty)
        #expect(ManualTargetInput(text: "abc") == .empty)
        #expect(ManualTargetInput(text: " ") == .empty)
    }

    @Test func aNumberFrom1To10000IsValid() {
        #expect(ManualTargetInput(text: "1") == .valid(1))
        #expect(ManualTargetInput(text: "900") == .valid(900))
        #expect(ManualTargetInput(text: "1800") == .valid(1800))
        #expect(ManualTargetInput(text: "10000") == .valid(10_000))
    }

    @Test func zeroAndMoreThan10000AreInvalidNotEmpty() {
        #expect(ManualTargetInput(text: "0") == .invalid)
        #expect(ManualTargetInput(text: "000") == .invalid)
        #expect(ManualTargetInput(text: "10001") == .invalid)
        #expect(ManualTargetInput(text: "99999") == .invalid)
    }

    @Test func onlyDigitsCountAndAtMostFiveOfThem() {
        #expect(ManualTargetInput.digits(in: "18a0") == "180")
        #expect(ManualTargetInput.digits(in: "1,800") == "1800")
        #expect(ManualTargetInput.digits(in: "123456") == "12345")
        #expect(ManualTargetInput(text: "1,800") == .valid(1800))
    }

    @Test func theRangeIsTheEnginesRange() {
        for kcal in [0, 1, 1199, 1200, 9_999, 10_000, 10_001] {
            let engine = EnergyTargetCalculator.assessManualTarget(Double(kcal), sex: nil) != .invalid
            let input = ManualTargetInput(text: String(kcal))
            #expect((input == .valid(Double(kcal))) == engine, "\(kcal)")
        }
        #expect(ManualTargetInput.maximumKcal == 10_000)
    }

    // MARK: Finish

    private func draft(sex: SexForEquation? = nil, manual: Double? = nil, trackWithout: Bool = false) -> ProfileDraft {
        var draft = ProfileDraft.starting(regionCode: "KR", currentYear: Self.year)
        draft.sex = sex
        draft.manualTargetKcal = manual
        draft.tracksWithoutGuide = trackWithout
        return draft
    }

    private func canFinish(_ draft: ProfileDraft, text: String? = nil, hidden: Bool = false) -> Bool {
        dailyGuideStepCanFinish(draft: draft, manualText: text, hideNumbers: hidden, currentYear: Self.year)
    }

    @Test func withoutASexValueFinishWaitsForAGuide() {
        #expect(!canFinish(draft()), "nothing calculated, no own number, not tracking without a guide")
        #expect(!canFinish(draft(), hidden: true), "hidden numbers: the only way out is Track without a guide")
        #expect(!canFinish(draft(), text: ""))
    }

    @Test func trackingWithoutAGuideResolvesIt() {
        #expect(canFinish(draft(trackWithout: true)))
        #expect(canFinish(draft(trackWithout: true), hidden: true))
    }

    @Test func anOwnNumberResolvesItEvenBelowTheMinimum() {
        #expect(canFinish(draft(manual: 1800), text: "1800"))
        #expect(canFinish(draft(manual: 900), text: "900"), "below the suggested minimum never blocks Finish")
        #expect(canFinish(draft(manual: 1), text: "1"))
    }

    @Test func aSexValueCalculatesAGuide() {
        #expect(canFinish(draft(sex: .male)))
        #expect(canFinish(draft(sex: .female), hidden: true))
    }

    @Test func aNumberThatCannotBeUsedIsNotDroppedSilently() {
        // The draft holds no own number for "0" or "99999", so only the text says what is on screen.
        #expect(!canFinish(draft(sex: .male), text: "0"))
        #expect(!canFinish(draft(sex: .male), text: "99999"))
        #expect(!canFinish(draft(), text: "0"))
        #expect(canFinish(draft(sex: .male), text: ""), "an empty field is just no own number")
    }

    @Test func aNumberThatCannotBeUsedStopsMattering() {
        // Tracking without a guide wins over the field (which is then off), and hidden numbers hide the field.
        #expect(canFinish(draft(sex: .male, trackWithout: true), text: "0"))
        #expect(canFinish(draft(sex: .male), text: "0", hidden: true))
    }
}

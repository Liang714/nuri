import Foundation
import Testing
import NuriDomain
@testable import ActivityEngine

@Suite struct DuplicateDetectorTests {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    func rec(_ id: String, type: String = "walking", offsetMin: Double = 0, duration: Double = 30,
             source: ActivityEnergySource = .manualMET) -> ActivityRecord {
        ActivityRecord(id: id, activityTypeId: type, start: t0.addingTimeInterval(offsetMin * 60),
                       durationMinutes: duration, source: source, externalId: nil)
    }

    @Test func overlapAbove80PercentIsDuplicate() {
        #expect(DuplicateDetector.isLikelyDuplicate(rec("a"), rec("b", offsetMin: 5, source: .healthPlatform)))
    }

    @Test func overlapBelow80PercentIsNot() {
        #expect(!DuplicateDetector.isLikelyDuplicate(rec("a"), rec("b", offsetMin: 7)))
    }

    @Test func differentTypeOrDurationIsNot() {
        #expect(!DuplicateDetector.isLikelyDuplicate(rec("a"), rec("b", type: "running")))
        #expect(!DuplicateDetector.isLikelyDuplicate(rec("a"), rec("b", duration: 60)))
    }

    @Test func sameRecordIsNotItsOwnDuplicate() {
        #expect(!DuplicateDetector.isLikelyDuplicate(rec("a"), rec("a")))
    }

    @Test func findsPairsOnce() {
        let pairs = DuplicateDetector.likelyDuplicates(in: [rec("a"), rec("b", offsetMin: 2), rec("c", offsetMin: 300)])
        #expect(pairs == [DuplicatePair(firstId: "a", secondId: "b")])
    }

    @Test func fingerprintIsStableAndSourceSpecific() {
        let f1 = DuplicateDetector.fingerprint(source: .healthPlatform, externalId: "HK-1", start: t0, durationMinutes: 30, activityTypeId: "walking")
        let f2 = DuplicateDetector.fingerprint(source: .healthPlatform, externalId: "HK-1", start: t0, durationMinutes: 30, activityTypeId: "walking")
        let f3 = DuplicateDetector.fingerprint(source: .wearable, externalId: "HK-1", start: t0, durationMinutes: 30, activityTypeId: "walking")
        #expect(f1 == f2)
        #expect(f1 != f3)
        #expect(f1.count == 64)
    }
}

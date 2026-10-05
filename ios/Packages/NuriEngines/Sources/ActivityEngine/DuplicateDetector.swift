import CryptoKit
import Foundation
import NuriDomain

public struct ActivityRecord: Sendable, Equatable {
    public let id: String
    public let activityTypeId: String
    public let start: Date
    public let durationMinutes: Double
    public let source: ActivityEnergySource
    public let externalId: String?

    public init(id: String, activityTypeId: String, start: Date, durationMinutes: Double,
                source: ActivityEnergySource, externalId: String?) {
        self.id = id
        self.activityTypeId = activityTypeId
        self.start = start
        self.durationMinutes = durationMinutes
        self.source = source
        self.externalId = externalId
    }

    var end: Date { start.addingTimeInterval(durationMinutes * 60) }
}

public struct DuplicatePair: Equatable, Sendable {
    public let firstId: String
    public let secondId: String
}

/// Spec §5.5: never silently double-count activity energy.
public enum DuplicateDetector {
    public static let overlapThreshold = 0.8

    /// Overlap divided by the longer duration, so it also requires similar durations.
    public static func overlapFraction(_ a: ActivityRecord, _ b: ActivityRecord) -> Double {
        let overlap = min(a.end, b.end).timeIntervalSince(max(a.start, b.start))
        let longer = max(a.durationMinutes, b.durationMinutes) * 60
        guard overlap > 0, longer > 0 else { return 0 }
        return overlap / longer
    }

    public static func isLikelyDuplicate(_ a: ActivityRecord, _ b: ActivityRecord) -> Bool {
        a.id != b.id && a.activityTypeId == b.activityTypeId && overlapFraction(a, b) > overlapThreshold
    }

    public static func likelyDuplicates(in records: [ActivityRecord]) -> [DuplicatePair] {
        let sorted = records.sorted { $0.start < $1.start }
        var pairs: [DuplicatePair] = []
        for i in sorted.indices {
            for j in sorted.indices where j > i {
                if sorted[j].start >= sorted[i].end { break }
                if isLikelyDuplicate(sorted[i], sorted[j]) {
                    pairs.append(DuplicatePair(firstId: sorted[i].id, secondId: sorted[j].id))
                }
            }
        }
        return pairs
    }

    /// Source-specific fingerprint for imported workouts (SHA-256 hex).
    public static func fingerprint(source: ActivityEnergySource, externalId: String?, start: Date,
                                   durationMinutes: Double, activityTypeId: String) -> String {
        let key = [
            source.rawValue,
            externalId ?? "",
            String(Int(start.timeIntervalSince1970)),
            String(Int(durationMinutes.rounded())),
            activityTypeId,
        ].joined(separator: "|")
        return SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

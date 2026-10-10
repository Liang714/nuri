import Foundation
import SwiftData
import Testing
@testable import Persistence

@MainActor
@Suite struct ConsentLogTests {
    @MainActor struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let log: SwiftDataConsentLog

        init() throws {
            container = try NuriStore.makeContainer(inMemory: true)
            context = container.mainContext
            log = SwiftDataConsentLog(context: context)
        }
    }

    static let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    static func granted(at date: Date = t0) -> ConsentEvent {
        ConsentEvent(kind: .granted, adultConfirmed: true, healthDataConsented: true, analyticsOptIn: true,
                     consentVersion: "2026-10-10", localeIdentifier: "ko_KR", recordedAt: date)
    }

    static func withdrawn(at date: Date) -> ConsentEvent {
        ConsentEvent(kind: .withdrawn, adultConfirmed: true, healthDataConsented: false, analyticsOptIn: false,
                     consentVersion: "2026-10-10", localeIdentifier: "ko_KR", recordedAt: date)
    }

    @Test func emptyStoreHasNoEvents() throws {
        let fx = try Fixture()
        #expect(try fx.log.events().isEmpty)
    }

    @Test func appendsGrantedThenWithdrawnAndReturnsBothInRecordedAtOrder() throws {
        let fx = try Fixture()
        let granted = Self.granted()
        let withdrawn = Self.withdrawn(at: Self.t0.addingTimeInterval(86_400))
        // Appended out of order on purpose: the log orders by recordedAt, not by insertion.
        try fx.log.append(withdrawn)
        try fx.log.append(granted)
        #expect(try fx.log.events() == [granted, withdrawn])
        #expect(try fx.context.fetchCount(FetchDescriptor<ConsentEventRecord>()) == 2)
    }

    @Test func equalTimestampsComeBackInAppendOrder() throws {
        let fx = try Fixture()
        let granted = Self.granted()
        var withdrawn = Self.withdrawn(at: Self.t0)
        withdrawn.localeIdentifier = "en_US"
        try fx.log.append(granted)
        try fx.log.append(withdrawn)
        #expect(try fx.log.events() == [granted, withdrawn])

        // Each append takes the next sequence number.
        let records = try fx.context.fetch(FetchDescriptor<ConsentEventRecord>(sortBy: [SortDescriptor(\.sequence)]))
        #expect(records.map(\.sequence) == [1, 2])
        #expect(records.map(\.kind) == ["granted", "withdrawn"])
    }

    @Test func sequenceDecidesTheOrderOfEqualTimestampsNotInsertionOrder() throws {
        let fx = try Fixture()
        // Twelve events with the same timestamp, inserted newest-sequence-first: SQLite gives no order for ties on its own.
        for number in (1...12).reversed() {
            fx.context.insert(ConsentEventRecord(kind: number.isMultiple(of: 2) ? "withdrawn" : "granted", adultConfirmed: true,
                                                 healthDataConsented: !number.isMultiple(of: 2), analyticsOptIn: false,
                                                 consentVersion: "v\(number)", localeIdentifier: "en_US", recordedAt: Self.t0,
                                                 sequence: number))
        }
        try fx.context.save()
        #expect(try fx.log.events().map(\.consentVersion) == (1...12).map { "v\($0)" })
    }

    @Test func sequenceContinuesFromTheHighestExistingValue() throws {
        let fx = try Fixture()
        fx.context.insert(ConsentEventRecord(kind: "granted", adultConfirmed: true, healthDataConsented: true, analyticsOptIn: false,
                                             consentVersion: "v", localeIdentifier: "en_US", recordedAt: Self.t0, sequence: 41))
        try fx.context.save()
        try fx.log.append(Self.withdrawn(at: Self.t0))
        let sequences = try fx.context.fetch(FetchDescriptor<ConsentEventRecord>(sortBy: [SortDescriptor(\.sequence)])).map(\.sequence)
        #expect(sequences == [41, 42])
    }

    @Test func everyFieldRoundTrips() throws {
        let fx = try Fixture()
        let event = ConsentEvent(kind: .granted, adultConfirmed: true, healthDataConsented: true, analyticsOptIn: false,
                                 consentVersion: "v-test", localeIdentifier: "en_US", recordedAt: Self.t0)
        try fx.log.append(event)
        let loaded = try #require(try fx.log.events().first)
        #expect(loaded.kind == .granted)
        #expect(loaded.adultConfirmed)
        #expect(loaded.healthDataConsented)
        #expect(loaded.analyticsOptIn == false)
        #expect(loaded.consentVersion == "v-test")
        #expect(loaded.localeIdentifier == "en_US")
        #expect(loaded.recordedAt == Self.t0)
    }

    @Test func recordsAreNeverMutatedByLaterAppends() throws {
        let fx = try Fixture()
        try fx.log.append(Self.granted())
        let firstSnapshot = try #require(try fx.log.events().first)

        try fx.log.append(Self.withdrawn(at: Self.t0.addingTimeInterval(60)))
        let after = try fx.log.events()

        #expect(after.count == 2)
        #expect(after[0] == firstSnapshot)
        #expect(after[0].kind == .granted)
        #expect(after[0].healthDataConsented)
        #expect(after[1].kind == .withdrawn)
    }

    @Test func eventsSurviveASeparateContextOnTheSameStore() throws {
        let fx = try Fixture()
        try fx.log.append(Self.granted())
        let other = SwiftDataConsentLog(context: ModelContext(fx.container))
        #expect(try other.events() == [Self.granted()])
    }

    /// A real save failure cannot be forced on an in-memory store, so the log's save step is a seam (`save:`) and this test
    /// makes it throw. What it pins is what the log does about the failure: nothing may stay pending in the context.
    @Test func aFailedSaveLeavesNoStrandedRecordBehind() throws {
        struct SaveFailure: Error {}
        let fx = try Fixture()
        let failing = SwiftDataConsentLog(context: fx.context, save: { _ in throw SaveFailure() })
        #expect(throws: SaveFailure.self) { try failing.append(Self.granted()) }

        // The failed grant is gone from the context, so the next successful save cannot write it by accident.
        #expect(try fx.log.events().isEmpty)
        #expect(!fx.context.hasChanges)
        try fx.log.append(Self.withdrawn(at: Self.t0.addingTimeInterval(60)))
        #expect(try fx.log.events().map(\.kind) == [.withdrawn])
        let records = try fx.context.fetch(FetchDescriptor<ConsentEventRecord>())
        #expect(records.map(\.sequence) == [1], "The failed append must not have used up a sequence number")
    }
}

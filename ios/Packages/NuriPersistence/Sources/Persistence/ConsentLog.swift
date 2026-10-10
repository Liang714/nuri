import Foundation
import SwiftData

/// One entry in the consent history (PIPA proof of consent).
public struct ConsentEvent: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case granted, withdrawn
    }

    public var kind: Kind
    public var adultConfirmed: Bool
    public var healthDataConsented: Bool
    public var analyticsOptIn: Bool
    public var consentVersion: String
    public var localeIdentifier: String
    public var recordedAt: Date

    public init(kind: Kind, adultConfirmed: Bool, healthDataConsented: Bool, analyticsOptIn: Bool,
                consentVersion: String, localeIdentifier: String, recordedAt: Date) {
        self.kind = kind
        self.adultConfirmed = adultConfirmed
        self.healthDataConsented = healthDataConsented
        self.analyticsOptIn = analyticsOptIn
        self.consentVersion = consentVersion
        self.localeIdentifier = localeIdentifier
        self.recordedAt = recordedAt
    }
}

/// Append-only: there is deliberately no update or delete. The history goes only when everything goes (`DataWiper`).
@MainActor
public protocol ConsentLogging {
    func append(_ event: ConsentEvent) throws
    /// Every event, oldest first by `recordedAt`, then by append order.
    func events() throws -> [ConsentEvent]
}

@MainActor
public final class SwiftDataConsentLog: ConsentLogging {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func append(_ event: ConsentEvent) throws {
        var latest = FetchDescriptor<ConsentEventRecord>(sortBy: [SortDescriptor(\.sequence, order: .reverse)])
        latest.fetchLimit = 1
        let next = (try context.fetch(latest).first?.sequence ?? 0) + 1
        context.insert(ConsentEventRecord(
            kind: event.kind.rawValue,
            adultConfirmed: event.adultConfirmed,
            healthDataConsented: event.healthDataConsented,
            analyticsOptIn: event.analyticsOptIn,
            consentVersion: event.consentVersion,
            localeIdentifier: event.localeIdentifier,
            recordedAt: event.recordedAt,
            sequence: next
        ))
        try context.save()
    }

    public func events() throws -> [ConsentEvent] {
        let descriptor = FetchDescriptor<ConsentEventRecord>(sortBy: [SortDescriptor(\.recordedAt), SortDescriptor(\.sequence)])
        return try context.fetch(descriptor).compactMap { record in
            // A kind this build does not know can only come from a newer store; it is skipped, never rewritten.
            guard let kind = ConsentEvent.Kind(rawValue: record.kind) else { return nil }
            return ConsentEvent(kind: kind, adultConfirmed: record.adultConfirmed,
                                healthDataConsented: record.healthDataConsented, analyticsOptIn: record.analyticsOptIn,
                                consentVersion: record.consentVersion, localeIdentifier: record.localeIdentifier,
                                recordedAt: record.recordedAt)
        }
    }
}

import Foundation
import Observation
import Persistence

enum OnboardingStage: String, Sendable {
    case welcome, consent, profile, complete
}

enum ConsentError: Error, Equatable, Sendable {
    case adultRequired, healthDataRequired
    /// The consent history could not be written, so consent is not granted: the proof must exist before the data does.
    case couldNotRecord
}

/// What the person agreed to, when, and under which consent text version (PIPA record keeping).
struct ConsentRecord: Codable, Equatable, Sendable {
    let adultConfirmed: Bool
    let healthDataConsented: Bool
    let analyticsOptIn: Bool
    let consentVersion: String
    let recordedAt: Date
}

@MainActor
@Observable
final class AppState {
    static let consentVersion = "2026-10-08"
    /// SHA-256 of the English and Korean consent copy that `consentVersion` covers (see `ConsentCopyTests`).
    /// When that test fails, the consent text changed: bump `consentVersion` so people consent again, then paste the new value here.
    static let consentCopyFingerprint = "52e6976413803f27ba3d126ac71792fc4b34d88b154b07d51b1389f245525c9e"

    private enum Keys {
        static let stage = "onboarding.stage"
        static let consent = "consent.record"
        static let hideNumbers = "display.hideNumbers"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let consentLog: (any ConsentLogging)?
    private(set) var stage: OnboardingStage
    private(set) var consent: ConsentRecord?
    private(set) var hideNumbers: Bool

    /// `profileExists` is asked once, at launch, to decide whether a stored `.complete` can be trusted.
    init(defaults: UserDefaults = .standard, consentLog: (any ConsentLogging)? = nil,
         profileExists: @MainActor () -> Bool = { false }) {
        self.defaults = defaults
        self.consentLog = consentLog
        let consent = defaults.data(forKey: Keys.consent).flatMap { try? Self.decoder.decode(ConsentRecord.self, from: $0) }
        let stored = defaults.string(forKey: Keys.stage).flatMap(OnboardingStage.init(rawValue:)) ?? .welcome
        self.consent = consent
        self.stage = Self.resolvedStage(stored: stored, consent: consent, profileExists: profileExists)
        self.hideNumbers = defaults.bool(forKey: Keys.hideNumbers)
    }

    /// Only the welcome screen leads to consent; later stages are not rewound by a stray call.
    func chooseGuest() {
        guard stage == .welcome else { return }
        setStage(.consent)
    }

    func recordConsent(adult: Bool, healthData: Bool, analytics: Bool, now: Date = .now) throws(ConsentError) {
        guard adult else { throw .adultRequired }
        guard healthData else { throw .healthDataRequired }
        let record = ConsentRecord(adultConfirmed: true, healthDataConsented: true, analyticsOptIn: analytics,
                                   consentVersion: Self.consentVersion, recordedAt: now)
        // The history comes first: if it cannot be written, nothing else changes and the person stays on consent.
        do { try consentLog?.append(Self.event(.granted, from: record, at: now)) } catch { throw .couldNotRecord }
        if let data = try? Self.encoder.encode(record) { defaults.set(data, forKey: Keys.consent) }
        consent = record
        setStage(.profile)
    }

    /// The profile is saved by the profile flow before this is called; only that stage leads to `.complete`.
    func completeProfile() {
        guard stage == .profile else { return }
        setStage(.complete)
    }

    /// Records that consent was withdrawn, carrying what had been agreed to. It changes no state: the caller wipes the
    /// data and then calls `startOver()`. A history that cannot be written must never stop the wipe, so a failure is ignored.
    func withdrawConsent(now: Date = .now) {
        guard let consent else { return }
        try? consentLog?.append(Self.event(.withdrawn, from: consent, at: now))
    }

    func setHideNumbers(_ hidden: Bool) {
        hideNumbers = hidden
        defaults.set(hidden, forKey: Keys.hideNumbers)
    }

    func startOver() {
        for key in [Keys.stage, Keys.consent, Keys.hideNumbers] { defaults.removeObject(forKey: key) }
        consent = nil
        hideNumbers = false
        stage = .welcome
    }

    private static func event(_ kind: ConsentEvent.Kind, from record: ConsentRecord, at date: Date) -> ConsentEvent {
        ConsentEvent(kind: kind, adultConfirmed: record.adultConfirmed, healthDataConsented: record.healthDataConsented,
                     analyticsOptIn: record.analyticsOptIn, consentVersion: record.consentVersion,
                     localeIdentifier: Locale.current.identifier, recordedAt: date)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// A stored `.profile` or `.complete` is trusted only with a consent record for the current consent text.
    /// A record for an older text sends the person back to consent; no record at all, back to welcome.
    /// A stored `.complete` also needs the profile it promises: without one the person returns to the profile step.
    private static func resolvedStage(stored: OnboardingStage, consent: ConsentRecord?,
                                      profileExists: @MainActor () -> Bool) -> OnboardingStage {
        guard stored == .profile || stored == .complete else { return stored }
        guard let consent else { return .welcome }
        guard consent.consentVersion == consentVersion else { return .consent }
        return stored == .complete && profileExists() ? .complete : .profile
    }

    private func setStage(_ newStage: OnboardingStage) {
        stage = newStage
        defaults.set(newStage.rawValue, forKey: Keys.stage)
    }
}

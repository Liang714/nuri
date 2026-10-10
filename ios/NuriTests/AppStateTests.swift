import Foundation
import Persistence
import Testing
@testable import Nuri

/// An in-memory consent history, so these tests stay off disk.
@MainActor
final class FakeConsentLog: ConsentLogging {
    struct Failure: Error {}

    private(set) var recorded: [ConsentEvent] = []
    var failsToAppend = false

    func append(_ event: ConsentEvent) throws {
        if failsToAppend { throw Failure() }
        recorded.append(event)
    }

    func events() throws -> [ConsentEvent] { recorded }
}

@MainActor
@Suite struct AppStateTests {
    func freshDefaults() -> UserDefaults {
        let name = "nuri.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func state(_ defaults: UserDefaults, log: FakeConsentLog? = nil, profileExists: Bool = false) -> AppState {
        AppState(defaults: defaults, consentLog: log, profileExists: { profileExists })
    }

    @Test func startsAtWelcomeWithNothingRecorded() {
        let s = AppState(defaults: freshDefaults())
        #expect(s.stage == .welcome)
        #expect(s.consent == nil)
        #expect(!s.hideNumbers)
    }

    @Test func guestPathMovesToConsent() {
        let s = AppState(defaults: freshDefaults())
        s.chooseGuest()
        #expect(s.stage == .consent)
    }

    @Test func consentRequiresAdultAndHealthData() {
        let s = AppState(defaults: freshDefaults())
        #expect(throws: ConsentError.adultRequired) { try s.recordConsent(adult: false, healthData: true, analytics: false) }
        #expect(throws: ConsentError.healthDataRequired) { try s.recordConsent(adult: true, healthData: false, analytics: false) }
        #expect(s.stage == .welcome)
        #expect(s.consent == nil)
    }

    @Test func refusedConsentLogsNothing() {
        let log = FakeConsentLog()
        let s = state(freshDefaults(), log: log)
        #expect(throws: ConsentError.adultRequired) { try s.recordConsent(adult: false, healthData: true, analytics: false) }
        #expect(log.recorded.isEmpty)
    }

    @Test func consentMovesToProfileAndSurvivesRelaunch() throws {
        let d = freshDefaults()
        let s = AppState(defaults: d)
        let when = Date(timeIntervalSince1970: 1_800_000_000)
        try s.recordConsent(adult: true, healthData: true, analytics: false, now: when)
        #expect(s.stage == .profile)
        let relaunched = AppState(defaults: d)
        #expect(relaunched.stage == .profile)
        #expect(relaunched.consent == ConsentRecord(adultConfirmed: true, healthDataConsented: true, analyticsOptIn: false,
                                                    consentVersion: AppState.consentVersion, recordedAt: when))
    }

    @Test func consentAppendsOneGrantedEvent() throws {
        let log = FakeConsentLog()
        let s = state(freshDefaults(), log: log)
        let when = Date(timeIntervalSince1970: 1_800_000_000)
        try s.recordConsent(adult: true, healthData: true, analytics: true, now: when)
        #expect(s.stage == .profile)
        #expect(log.recorded == [ConsentEvent(kind: .granted, adultConfirmed: true, healthDataConsented: true,
                                              analyticsOptIn: true, consentVersion: AppState.consentVersion,
                                              localeIdentifier: Locale.current.identifier, recordedAt: when)])
    }

    @Test func consentLogRecordsTheCurrentLocale() throws {
        let log = FakeConsentLog()
        try state(freshDefaults(), log: log).recordConsent(adult: true, healthData: true, analytics: false)
        #expect(log.recorded.first?.localeIdentifier == Locale.current.identifier)
        #expect(log.recorded.first?.localeIdentifier.isEmpty == false)
    }

    @Test func consentIsNotGrantedWhenItCannotBeRecorded() {
        let d = freshDefaults()
        let log = FakeConsentLog()
        log.failsToAppend = true
        let s = state(d, log: log)
        s.chooseGuest()
        #expect(throws: ConsentError.couldNotRecord) { try s.recordConsent(adult: true, healthData: true, analytics: false) }
        #expect(s.stage == .consent && s.consent == nil)
        let relaunched = AppState(defaults: d)
        #expect(relaunched.stage == .consent && relaunched.consent == nil)
    }

    @Test func completingTheProfileFinishesOnboarding() throws {
        let s = state(freshDefaults())
        try s.recordConsent(adult: true, healthData: true, analytics: false)
        s.completeProfile()
        #expect(s.stage == .complete)
    }

    @Test func completeStageWithCurrentConsentAndAProfileIsTrustedOnRelaunch() throws {
        let d = freshDefaults()
        let s = state(d)
        try s.recordConsent(adult: true, healthData: true, analytics: false)
        s.completeProfile()
        #expect(state(d, profileExists: true).stage == .complete)
    }

    @Test func completeStageWithoutAProfileReturnsToTheProfileStep() throws {
        let d = freshDefaults()
        let s = state(d)
        try s.recordConsent(adult: true, healthData: true, analytics: false)
        s.completeProfile()
        let relaunched = state(d, profileExists: false)
        #expect(relaunched.stage == .profile)
        #expect(relaunched.consent != nil)
    }

    @Test func completingTheProfileOnlyActsFromTheProfileStage() throws {
        let s = state(freshDefaults())
        s.completeProfile()
        #expect(s.stage == .welcome)
        s.chooseGuest()
        s.completeProfile()
        #expect(s.stage == .consent)
        try s.recordConsent(adult: true, healthData: true, analytics: false)
        s.completeProfile()
        s.completeProfile()
        #expect(s.stage == .complete)
    }

    @Test func profileStageNeedsCurrentConsent() throws {
        let noRecord = freshDefaults()
        noRecord.set("profile", forKey: "onboarding.stage")
        #expect(state(noRecord).stage == .welcome)

        let stale = freshDefaults()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let old = ConsentRecord(adultConfirmed: true, healthDataConsented: true, analyticsOptIn: false,
                                consentVersion: "old", recordedAt: Date(timeIntervalSince1970: 1_700_000_000))
        stale.set(try encoder.encode(old), forKey: "consent.record")
        stale.set("profile", forKey: "onboarding.stage")
        #expect(state(stale).stage == .consent)
    }

    @Test func withdrawingConsentAppendsAWithdrawnEventWithThePreviousItems() throws {
        let log = FakeConsentLog()
        let s = state(freshDefaults(), log: log)
        let granted = Date(timeIntervalSince1970: 1_800_000_000)
        let withdrawn = Date(timeIntervalSince1970: 1_800_086_400)
        try s.recordConsent(adult: true, healthData: true, analytics: true, now: granted)
        s.withdrawConsent(now: withdrawn)
        #expect(log.recorded.count == 2)
        #expect(log.recorded.last == ConsentEvent(kind: .withdrawn, adultConfirmed: true, healthDataConsented: true,
                                                  analyticsOptIn: true, consentVersion: AppState.consentVersion,
                                                  localeIdentifier: Locale.current.identifier, recordedAt: withdrawn))
        #expect(s.stage == .profile, "the caller wipes the data and then starts over")
        #expect(s.consent != nil)
    }

    @Test func withdrawingStaleConsentCarriesTheVersionThatWasAgreedTo() throws {
        let d = freshDefaults()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let old = ConsentRecord(adultConfirmed: true, healthDataConsented: true, analyticsOptIn: false,
                                consentVersion: "old", recordedAt: Date(timeIntervalSince1970: 1_700_000_000))
        d.set(try encoder.encode(old), forKey: "consent.record")
        d.set("complete", forKey: "onboarding.stage")
        let log = FakeConsentLog()
        let s = state(d, log: log, profileExists: true)
        s.withdrawConsent(now: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(log.recorded.map(\.kind) == [.withdrawn])
        #expect(log.recorded.first?.consentVersion == "old")
    }

    @Test func withdrawingWithoutConsentRecordsNothing() {
        let log = FakeConsentLog()
        state(freshDefaults(), log: log).withdrawConsent()
        #expect(log.recorded.isEmpty)
    }

    @Test func withdrawingStillWorksWhenTheLogCannotBeWritten() throws {
        let log = FakeConsentLog()
        let s = state(freshDefaults(), log: log)
        try s.recordConsent(adult: true, healthData: true, analytics: false)
        log.failsToAppend = true
        s.withdrawConsent()
        s.startOver()
        #expect(s.stage == .welcome)
    }

    @Test func completedStageWithoutConsentIsNotTrusted() {
        let d = freshDefaults()
        d.set("complete", forKey: "onboarding.stage")
        #expect(AppState(defaults: d).stage == .welcome)
    }

    @Test func chooseGuestOnlyActsFromWelcome() throws {
        let s = AppState(defaults: freshDefaults())
        try s.recordConsent(adult: true, healthData: true, analytics: false)
        s.chooseGuest()
        #expect(s.stage == .profile)
    }

    @Test func staleConsentVersionSendsPersonBackToConsent() throws {
        let d = freshDefaults()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let stale = ConsentRecord(adultConfirmed: true, healthDataConsented: true, analyticsOptIn: false,
                                  consentVersion: "old", recordedAt: Date(timeIntervalSince1970: 1_700_000_000))
        d.set(try encoder.encode(stale), forKey: "consent.record")
        d.set("complete", forKey: "onboarding.stage")
        let relaunched = AppState(defaults: d)
        #expect(relaunched.stage == .consent)
        #expect(relaunched.consent == stale)
    }

    @Test func consentRecordIsStoredWithISO8601Date() throws {
        let d = freshDefaults()
        let s = AppState(defaults: d)
        try s.recordConsent(adult: true, healthData: true, analytics: false, now: Date(timeIntervalSince1970: 1_800_000_000))
        let data = try #require(d.data(forKey: "consent.record"))
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("2027-01-15T08:00:00Z"))
    }

    @Test func hideNumbersPersists() {
        let d = freshDefaults()
        AppState(defaults: d).setHideNumbers(true)
        #expect(AppState(defaults: d).hideNumbers)
    }

    @Test func startOverClearsEverything() throws {
        let d = freshDefaults()
        let s = AppState(defaults: d)
        try s.recordConsent(adult: true, healthData: true, analytics: true)
        s.setHideNumbers(true)
        s.startOver()
        #expect(s.stage == .welcome && s.consent == nil && !s.hideNumbers)
        let relaunched = AppState(defaults: d)
        #expect(relaunched.stage == .welcome && relaunched.consent == nil && !relaunched.hideNumbers)
    }

    @Test func accountSignInIsNotAvailableYet() {
        let auth = UnavailableAuthService()
        for method in SignInMethod.allCases { #expect(auth.availability(for: method) == .comingLater) }
    }
}

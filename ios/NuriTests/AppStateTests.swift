import Foundation
import Testing
@testable import Nuri

@MainActor
@Suite struct AppStateTests {
    func freshDefaults() -> UserDefaults {
        let name = "nuri.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
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

    @Test func consentCompletesAndSurvivesRelaunch() throws {
        let d = freshDefaults()
        let s = AppState(defaults: d)
        let when = Date(timeIntervalSince1970: 1_800_000_000)
        try s.recordConsent(adult: true, healthData: true, analytics: false, now: when)
        #expect(s.stage == .complete)
        let relaunched = AppState(defaults: d)
        #expect(relaunched.stage == .complete)
        #expect(relaunched.consent == ConsentRecord(adultConfirmed: true, healthDataConsented: true, analyticsOptIn: false,
                                                    consentVersion: AppState.consentVersion, recordedAt: when))
    }

    @Test func completedStageWithoutConsentIsNotTrusted() {
        let d = freshDefaults()
        d.set("complete", forKey: "onboarding.stage")
        #expect(AppState(defaults: d).stage == .welcome)
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

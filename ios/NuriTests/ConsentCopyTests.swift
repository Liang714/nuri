import CryptoKit
import Foundation
import Testing
@testable import Nuri

/// Pins the consent screen copy to `AppState.consentVersion`. A consent record stores the version it was given under,
/// so changing the words people agreed to without changing the version would misstate what they consented to.
@MainActor
@Suite struct ConsentCopyTests {
    /// Every string on the consent screen that says what is stored, why, and what the person agrees to.
    static let consentKeys = [
        "I am 18 or older",
        "Nuri is made for adults.",
        "Store my food and activity data",
        "Needed to run Nuri. This is health information, kept private and never sold or used to target ads. Export or delete it anytime.",
        "Share anonymous usage stats",
        "Helps improve Nuri. Never includes foods, notes or health data.",
        "Nuri gives general wellness estimates, not medical advice. Food energy, nutrients and exercise vary by person, preparation and device. For medical or nutrition guidance, talk to a qualified clinician.",
    ]

    private static let missing = "\u{0}missing"

    /// The compiled string for `key` in one language's table inside the app bundle.
    private static func value(of key: String, language: String) throws -> String {
        let appBundle = Bundle(for: AppState.self)
        let path = try #require(appBundle.path(forResource: language, ofType: "lproj"), "The app bundle has no \(language) localization")
        let table = try #require(Bundle(path: path))
        let value = table.localizedString(forKey: key, value: missing, table: nil)
        try #require(value != missing, "Consent key \(key.debugDescription) is not in the \(language) strings; update ConsentCopyTests.consentKeys")
        return value
    }

    static func fingerprint() throws -> String {
        var text = ""
        for key in consentKeys {
            for language in ["en", "ko"] {
                text += "\(language)\u{1F}\(key)\u{1F}\(try value(of: key, language: language))\u{1E}"
            }
        }
        return SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    @Test func consentCopyMatchesTheFingerprintForTheCurrentConsentVersion() throws {
        let current = try Self.fingerprint()
        #expect(
            current == AppState.consentCopyFingerprint,
            """
            The consent screen copy changed (English or Korean). Bump AppState.consentVersion (now \(AppState.consentVersion.debugDescription)) \
            so people are asked to consent again, then set AppState.consentCopyFingerprint to \(current.debugDescription).
            """
        )
    }

    @Test func everyConsentKeyHasDistinctEnglishAndKoreanText() throws {
        for key in Self.consentKeys {
            let english = try Self.value(of: key, language: "en")
            let korean = try Self.value(of: key, language: "ko")
            #expect(!english.isEmpty && !korean.isEmpty)
            #expect(english != korean, "\(key.debugDescription) has no Korean translation")
        }
    }
}

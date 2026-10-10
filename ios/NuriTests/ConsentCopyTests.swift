import CryptoKit
import Foundation
import Testing
@testable import Nuri

/// Pins the consent screen copy to `AppState.consentVersion`. A consent record stores the version it was given under,
/// so changing the words people agreed to without changing the version would misstate what they consented to.
@MainActor
@Suite struct ConsentCopyTests {
    /// Every string on the consent screen that says what is stored, why, and what the person agrees to.
    /// `ConsentCopy` is the single source, so a new consent string cannot be forgotten here.
    static let consentKeys = ConsentCopy.all.map(\.key)

    private static let missing = "\u{0}missing"

    /// The compiled string for `key` in one language's table inside the app bundle.
    private static func value(of key: String, language: String) throws -> String {
        let appBundle = Bundle(for: AppState.self)
        let path = try #require(appBundle.path(forResource: language, ofType: "lproj"), "The app bundle has no \(language) localization")
        let table = try #require(Bundle(path: path))
        let value = table.localizedString(forKey: key, value: missing, table: nil)
        try #require(value != missing, "Consent key \(key.debugDescription) is not in the \(language) strings; add it to Localizable.xcstrings with English and Korean values, then bump AppState.consentVersion and consentCopyFingerprint")
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

    /// `ConsentView` must draw every visible string from `ConsentCopy`; a quoted literal would escape the fingerprint.
    @Test func consentViewUsesOnlyConsentCopy() throws {
        // #filePath is .../ios/NuriTests/ConsentCopyTests.swift; the view is .../ios/App/Onboarding/ConsentView.swift.
        let iosRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let view = iosRoot.appendingPathComponent("App/Onboarding/ConsentView.swift")
        let source = try String(contentsOf: view, encoding: .utf8)
        let literal = try Regex(#"\b(Text|Label|Button|Toggle|Section|NavigationLink|LabeledContent|Link|navigationTitle|accessibilityLabel|row)\(\s*(verbatim:\s*)?""#)
        let offenders = source.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            .filter { $0.element.contains(literal) }
            .map { "line \($0.offset + 1): \($0.element.trimmingCharacters(in: .whitespaces))" }
        #expect(offenders.isEmpty, "ConsentView.swift has quoted strings; move them into ConsentCopy: \(offenders)")
    }
}

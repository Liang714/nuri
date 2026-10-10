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

    // MARK: - ConsentView shows only ConsentCopy

    /// `#filePath` is .../ios/NuriTests/ConsentCopyTests.swift; the app sources are .../ios/App/.
    private static func appSource(_ path: String) throws -> String {
        let iosRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: iosRoot.appendingPathComponent("App").appendingPathComponent(path), encoding: .utf8)
    }

    /// `ConsentView` must draw every visible string from `ConsentCopy`. Any string literal there, in any shape, would
    /// escape the fingerprint; only `.accessibilityIdentifier("...")` values may stay.
    @Test func consentViewUsesOnlyConsentCopy() throws {
        let source = try Self.appSource("Onboarding/ConsentView.swift")
        let literals = SwiftSourceScanner.stringLiterals(in: source)
        #expect(literals.contains { $0.isAccessibilityIdentifier }, "The scan found no .accessibilityIdentifier in ConsentView.swift; is it reading the right file?")
        let offenders = literals
            .filter { !$0.isAccessibilityIdentifier }
            .map { "line \($0.line): \($0.text.debugDescription)" }
        #expect(offenders.isEmpty, "ConsentView.swift has string literals; move them into ConsentCopy (only .accessibilityIdentifier values may stay): \(offenders)")
    }

    /// The string constants declared in ConsentCopy.swift, by name, with their keys.
    private static func declaredConstants() throws -> [String: String] {
        let declaration = try Regex(#"^\s*static let (\w+): LocalizedStringResource = "(.*)"\s*$"#)
        var declared: [String: String] = [:]
        for line in try appSource("ConsentCopy.swift").split(separator: "\n") {
            if let match = line.firstMatch(of: declaration), let name = match.output[1].substring, let key = match.output[2].substring {
                declared[String(name)] = String(key)
            }
        }
        return declared
    }

    @Test func everyConsentCopyConstantIsPinnedOrChrome() throws {
        let declared = try Self.declaredConstants()
        let pinned = Set(ConsentCopy.all.map(\.key))
        let chrome = Set(ConsentCopy.chrome.map(\.key))
        #expect(declared.count == pinned.count + chrome.count, "Each ConsentCopy constant must be in exactly one of all or chrome")
        #expect(Set(declared.values) == pinned.union(chrome), "A ConsentCopy constant is in neither all nor chrome (or a list names a key that has no constant)")
        #expect(pinned.isDisjoint(with: chrome), "A string is in both all and chrome")

        // What the view actually shows: every ConsentCopy.<name> in its code (comments excluded) must be pinned or chrome.
        let view = SwiftSourceScanner.scan(try Self.appSource("Onboarding/ConsentView.swift")).code
        let reference = try Regex(#"ConsentCopy\.(\w+)"#)
        let used = Set(view.matches(of: reference).compactMap { $0.output[1].substring.map(String.init) })
        #expect(!used.isEmpty, "ConsentView does not reference ConsentCopy at all")
        for name in used.sorted() {
            guard let key = declared[name] else {
                Issue.record("ConsentView uses ConsentCopy.\(name), which is not a string constant declared in ConsentCopy.swift")
                continue
            }
            #expect(pinned.contains(key) || chrome.contains(key), "ConsentCopy.\(name) is shown on the consent screen but is in neither ConsentCopy.all nor ConsentCopy.chrome")
        }
    }

    /// The fingerprint reads strings from the app bundle's default table; a resource pointing at another table or bundle
    /// would be shown but never hashed. (The compiler fills in the bundle as `.atURL(<the app bundle>)`, not `.main`.)
    @Test func consentResourcesUseTheDefaultTableAndTheAppBundle() {
        let appBundle = Bundle(for: AppState.self).bundleURL.resolvingSymlinksInPath().path
        for resource in ConsentCopy.all + ConsentCopy.chrome {
            #expect(resource.table == nil, "\(resource.key.debugDescription) uses table \(resource.table.debugDescription)")
            let bundle: URL
            switch resource.bundle {
            case .main: bundle = Bundle.main.bundleURL
            case .forClass(let type): bundle = Bundle(for: type).bundleURL
            case .atURL(let url): bundle = url
            @unknown default: bundle = URL(fileURLWithPath: "/unknown")
            }
            #expect(bundle.resolvingSymlinksInPath().path == appBundle, "\(resource.key.debugDescription) is not in the app bundle: \(bundle)")
        }
    }
}

// MARK: - Swift string-literal scanner

/// A string literal in Swift source.
struct SourceStringLiteral: Equatable {
    /// The source text between the delimiters, escapes and interpolations unprocessed.
    let text: String
    /// 1-based line of the opening delimiter.
    let line: Int
    /// True when it is the whole argument of `.accessibilityIdentifier(...)`.
    let isAccessibilityIdentifier: Bool
}

/// Finds every string literal in Swift source: normal `"..."` with escapes and `\(...)` interpolations (whose own
/// literals are found too), raw `#"..."#`, and multiline `"""..."""`. Comments (`//`, nested `/* */`) are skipped, and a
/// comment marker inside a literal is part of the literal.
enum SwiftSourceScanner {
    /// The source with comments removed, and every string literal in it, in order of their opening delimiters.
    static func scan(_ source: String) -> (code: String, literals: [SourceStringLiteral]) {
        var lexer = Lexer(source)
        lexer.scanCode(inInterpolation: false)
        return (String(String.UnicodeScalarView(lexer.code)), lexer.literals)
    }

    static func stringLiterals(in source: String) -> [SourceStringLiteral] { scan(source).literals }

    private struct Lexer {
        let scalars: [Unicode.Scalar]
        var index = 0
        var line = 1
        var code: [Unicode.Scalar] = []
        var literals: [SourceStringLiteral] = []

        init(_ source: String) { scalars = Array(source.unicodeScalars) }

        func scalar(at position: Int) -> Unicode.Scalar? { position < scalars.count ? scalars[position] : nil }

        func has(_ text: String, at position: Int) -> Bool {
            var position = position
            for expected in text.unicodeScalars {
                guard scalar(at: position) == expected else { return false }
                position += 1
            }
            return true
        }

        /// Copies one scalar of code (or literal text) through to `code`.
        mutating func advance() {
            let c = scalars[index]
            code.append(c)
            if c == "\n" { line += 1 }
            index += 1
        }

        /// Scans code to the end of input, or, inside a `\(...)` interpolation, up to and including its closing parenthesis.
        mutating func scanCode(inInterpolation: Bool) {
            var depth = 0
            while let c = scalar(at: index) {
                if has("//", at: index) {
                    while let next = scalar(at: index), next != "\n" { index += 1 }
                    code.append(" ")
                } else if has("/*", at: index) {
                    skipBlockComment()
                } else if let hashes = stringDelimiterHashes(at: index) {
                    scanString(hashes: hashes)
                } else {
                    if inInterpolation {
                        if c == "(" { depth += 1 }
                        if c == ")" {
                            if depth == 0 { advance(); return }
                            depth -= 1
                        }
                    }
                    advance()
                }
            }
        }

        /// The number of `#` before the opening quote when a string literal starts at `position`.
        func stringDelimiterHashes(at position: Int) -> Int? {
            var hashes = 0
            while scalar(at: position + hashes) == "#" { hashes += 1 }
            return scalar(at: position + hashes) == "\"" ? hashes : nil
        }

        mutating func skipBlockComment() {
            var depth = 0
            while let c = scalar(at: index) {
                if has("/*", at: index) {
                    depth += 1
                    index += 2
                } else if has("*/", at: index) {
                    depth -= 1
                    index += 2
                    if depth == 0 { break }
                } else {
                    if c == "\n" { line += 1; code.append("\n") }
                    index += 1
                }
            }
            code.append(" ")
        }

        mutating func scanString(hashes: Int) {
            let openingLine = line
            let hashString = String(repeating: "#", count: hashes)
            let isMultiline = has("\"\"\"", at: index + hashes)
            let quotes = isMultiline ? "\"\"\"" : "\""
            let terminator = quotes + hashString
            let afterDirectCall = Self.endsWithIdentifierCall(code)

            let slot = literals.count
            literals.append(SourceStringLiteral(text: "", line: openingLine, isAccessibilityIdentifier: false))
            for _ in 0..<(hashes + quotes.unicodeScalars.count) { advance() }

            let contentStart = index
            while let c = scalar(at: index), !has(terminator, at: index) {
                if c == "\\", has(hashString, at: index + 1) {
                    let afterEscape = index + 1 + hashes
                    for _ in 0..<(1 + hashes) { advance() }
                    if scalar(at: afterEscape) == "(" {
                        advance()
                        scanCode(inInterpolation: true)
                    } else if scalar(at: afterEscape) != nil {
                        advance()   // the escaped character, e.g. a quote or a backslash
                    }
                } else {
                    advance()
                }
            }
            let text = String(String.UnicodeScalarView(scalars[contentStart..<index]))
            if has(terminator, at: index) {
                for _ in 0..<terminator.unicodeScalars.count { advance() }
            }

            var next = index
            while let c = scalar(at: next), c.properties.isWhitespace { next += 1 }
            literals[slot] = SourceStringLiteral(text: text, line: openingLine,
                                                 isAccessibilityIdentifier: afterDirectCall && scalar(at: next) == ")")
        }

        /// True when the code so far ends with `.accessibilityIdentifier(`, ignoring whitespace.
        static func endsWithIdentifierCall(_ code: [Unicode.Scalar]) -> Bool {
            let tail = code.suffix(200).filter { !$0.properties.isWhitespace }
            return String(String.UnicodeScalarView(tail)).hasSuffix(".accessibilityIdentifier(")
        }
    }
}

@Suite struct SwiftSourceScannerTests {
    struct Fixture: Sendable, CustomTestStringConvertible {
        let name: String
        let source: String
        /// Literals that ConsentView must not contain, in source order.
        var disallowed: [String] = []
        /// Literals that are the argument of `.accessibilityIdentifier(`.
        var allowed: [String] = []
        var testDescription: String { name }
    }

    static let fixtures: [Fixture] = [
        Fixture(name: "second argument of row", source: ##"""
            Toggle(isOn: $analytics) { row(ConsentCopy.analyticsTitle, "Shares everything we can think of") }
            """##, disallowed: ["Shares everything we can think of"]),
        Fixture(name: "two literals in one call", source: ##"""
            row("First", "Second")
            """##, disallowed: ["First", "Second"]),
        Fixture(name: "literal on a continuation line", source: ##"""
            row(ConsentCopy.healthTitle,
                "Needed to run Nuri.")
            """##, disallowed: ["Needed to run Nuri."]),
        Fixture(name: "Text with the literal on the next line", source: ##"""
            Text(
                "Hello")
            """##, disallowed: ["Hello"]),
        Fixture(name: "LocalizedStringKey", source: ##"""
            Text(LocalizedStringKey("Hello"))
            """##, disallowed: ["Hello"]),
        Fixture(name: "String(localized:)", source: ##"""
            Text(String(localized: "Hello"))
            """##, disallowed: ["Hello"]),
        Fixture(name: "raw string", source: ##"""
            Text(#"Hello "there""#)
            """##, disallowed: [#"Hello "there""#]),
        Fixture(name: "accessibilityHint", source: ##"""
            Text(ConsentCopy.disclaimer).accessibilityHint("Double tap to open")
            """##, disallowed: ["Double tap to open"]),
        Fixture(name: "Picker title", source: ##"""
            Picker("Choose", selection: $choice) { Text(ConsentCopy.adultTitle).tag(1) }
            """##, disallowed: ["Choose"]),
        Fixture(name: "multiline literal", source: ##"""
            Text("""
                Hello
                there
                """)
            """##, disallowed: ["Hello\n    there"]),
        Fixture(name: "escaped quote does not end the literal", source: ##"""
            Text("He said \"hi\"")
            """##, disallowed: [#"He said \"hi\""#]),
        Fixture(name: "interpolation hides further literals", source: ##"""
            Text("Total \(count > 1 ? "many" : "one")")
            """##, disallowed: [#"Total \(count > 1 ? "many" : "one")"#, "many", "one"]),
        Fixture(name: "empty literal", source: ##"""
            Text("")
            """##, disallowed: [""]),
        Fixture(name: "line and block comments are ignored", source: ##"""
            // Text("line comment")
            /* Text("block comment") */
            /* outer /* nested */ Text("still comment") */
            Text(ConsentCopy.disclaimer) // "trailing"
            """##, disallowed: []),
        Fixture(name: "comment markers inside a literal do not start a comment", source: ##"""
            Text("https://example.com /* b */") // note
            """##, disallowed: ["https://example.com /* b */"]),
        Fixture(name: "compiler directives are not literals", source: ##"""
            let path = #filePath
            #if DEBUG
            #endif
            """##, disallowed: []),
        Fixture(name: "accessibilityIdentifier is allowed", source: ##"""
            Text(ConsentCopy.adultTitle).accessibilityIdentifier("consent.adult")
            """##, allowed: ["consent.adult"]),
        Fixture(name: "accessibilityIdentifier across lines is allowed", source: ##"""
            Toggle(isOn: $adult) { Text(ConsentCopy.adultTitle) }
                .accessibilityIdentifier(
                    "consent.adult"
                )
            """##, allowed: ["consent.adult"]),
        Fixture(name: "accessibilityIdentifier built from pieces is not allowed", source: ##"""
            .accessibilityIdentifier("consent." + name)
            """##, disallowed: ["consent."]),
        Fixture(name: "a literal after an identifier call is still caught", source: ##"""
            Text(ConsentCopy.adultTitle).accessibilityIdentifier("consent.adult").accessibilityHint("Hint")
            """##, disallowed: ["Hint"], allowed: ["consent.adult"]),
    ]

    @Test(arguments: SwiftSourceScannerTests.fixtures)
    func findsEveryLiteralAndAllowsOnlyIdentifiers(_ fixture: Fixture) {
        let found = SwiftSourceScanner.stringLiterals(in: fixture.source)
        let trim = { (text: String) in text.trimmingCharacters(in: .whitespacesAndNewlines) }
        #expect(found.filter { !$0.isAccessibilityIdentifier }.map { trim($0.text) } == fixture.disallowed.map(trim))
        #expect(found.filter(\.isAccessibilityIdentifier).map { trim($0.text) } == fixture.allowed.map(trim))
    }

    @Test func reportsTheLineOfEachLiteral() {
        let found = SwiftSourceScanner.stringLiterals(in: "a\n// c\nrow(x,\n  \"B\")\n")
        #expect(found.map(\.line) == [4])
    }

    @Test func codeKeepsNoCommentText() {
        let code = SwiftSourceScanner.scan("a // one\nb /* two */ c /* x /* y */ z */ d \"/* kept */\"").code
        #expect(!code.contains("one") && !code.contains("two") && !code.contains("y"))
        #expect(code.contains("kept") && code.contains("a") && code.contains("d"))
    }
}

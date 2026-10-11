import Foundation
import Testing
@testable import Nuri

/// Guards the profile screens' strings: every string the profile views and the consent alert show is a catalog key,
/// and English and Korean agree on their format specifiers (a Korean string with a missing or reordered `%@` shows
/// wrong text or crashes at runtime).
@MainActor
@Suite struct ProfileCopyTests {
    private static let iosRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    private struct Entry {
        let english: String
        let korean: String
    }

    private static func catalog() throws -> [String: Entry] {
        let url = iosRoot.appendingPathComponent("App").appendingPathComponent("Localizable.xcstrings")
        let root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: [String: Any]])
        var result: [String: Entry] = [:]
        for (key, value) in strings {
            func text(_ language: String) -> String? {
                let localizations = value["localizations"] as? [String: Any]
                let unit = (localizations?[language] as? [String: Any])?["stringUnit"] as? [String: Any]
                return unit?["value"] as? String
            }
            if let english = text("en"), let korean = text("ko") { result[key] = Entry(english: english, korean: korean) }
        }
        return result
    }

    /// Format specifiers by 1-based argument position: `%@`, `%lld` and `%1$@` / `%2$lld`.
    private static func specifiers(in text: String) -> [Int: String] {
        let pattern = #/%(?:(?<position>\d+)\$)?(?<type>ll[dux]|l[dux]|[@dux]|l?f)/#
        var result: [Int: String] = [:]
        var next = 1
        for match in text.matches(of: pattern) {
            let position = match.output.position.flatMap { Int($0) } ?? next
            result[position] = String(match.output.type)
            next += 1
        }
        return result
    }

    @Test func englishAndKoreanUseTheSameFormatSpecifiers() throws {
        for (key, entry) in try Self.catalog() where key.contains("%") {
            #expect(Self.specifiers(in: entry.english) == Self.specifiers(in: key), "English value of \(key.debugDescription) differs from its key")
            #expect(Self.specifiers(in: entry.korean) == Self.specifiers(in: entry.english),
                    "Korean \(entry.korean.debugDescription) must take the same arguments as \(key.debugDescription)")
        }
    }

    @Test func theSpecifierReaderUnderstandsPositionalKorean() {
        #expect(Self.specifiers(in: "%2$lld단계 중 %1$lld단계") == [1: "lld", 2: "lld"])
        #expect(Self.specifiers(in: "Step %lld of %lld") == [1: "lld", 2: "lld"])
        #expect(Self.specifiers(in: "몸무게를 %@에서 %@ 사이로") == [1: "@", 2: "@"])
        #expect(Self.specifiers(in: "No arguments") == [:])
    }

    /// The scan cannot know an interpolation's type, so a `\(...)` stands for any specifier.
    private static func matches(_ literal: String, key: String) -> Bool {
        var pattern = ""
        var rest = Substring(literal)
        while let start = rest.range(of: "\\(") {
            pattern += NSRegularExpression.escapedPattern(for: String(rest[..<start.lowerBound]))
            // Skip to the matching close parenthesis.
            var depth = 1
            var index = start.upperBound
            while index < rest.endIndex, depth > 0 {
                if rest[index] == "(" { depth += 1 } else if rest[index] == ")" { depth -= 1 }
                index = rest.index(after: index)
            }
            pattern += #"%(?:\d+\$)?(?:ll[dux]|l[dux]|[@dux]|l?f)"#
            rest = rest[index...]
        }
        pattern += NSRegularExpression.escapedPattern(for: String(rest))
        return key.range(of: "^" + pattern + "$", options: .regularExpression) != nil
    }

    /// Literals in these files that are not copy: an empty string or a single character (a separator), an SF Symbol name,
    /// an accessibility identifier handed on as an argument (they all start with "profile.").
    private static func isCopy(_ literal: String) -> Bool {
        literal.count > 1 && literal != "checkmark" && !literal.hasPrefix("profile.")
    }

    @Test func everyStringLiteralInTheProfileViewsIsACatalogKey() throws {
        let keys = Set(try Self.catalog().keys)
        let folder = Self.iosRoot.appendingPathComponent("App/Onboarding/Profile")
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).filter { $0.pathExtension == "swift" }
        #expect(files.count >= 4, "Expected the profile sources in \(folder.path)")
        var literalCount = 0
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for literal in SwiftSourceScanner.stringLiterals(in: source) where !literal.isAccessibilityIdentifier {
                literalCount += 1
                if !Self.isCopy(literal.text) { continue }
                #expect(keys.contains { Self.matches(literal.text, key: $0) },
                        "\(file.lastPathComponent):\(literal.line) \(literal.text.debugDescription) is not in Localizable.xcstrings")
            }
        }
        #expect(literalCount > 50, "The scan found only \(literalCount) literals; is it reading the right files?")
    }

    @Test func theConsentScreenChromeIsInTheCatalogWithKorean() throws {
        let catalog = try Self.catalog()
        for resource in ConsentCopy.chrome {
            let entry = try #require(catalog[resource.key], "\(resource.key.debugDescription) is not in Localizable.xcstrings")
            #expect(!entry.korean.isEmpty)
        }
    }
}

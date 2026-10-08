import Foundation

/// A light plausibility check before sending a sign-in code. The server is the real validator.
enum EmailValidator {
    static func isPlausible(_ text: String) -> Bool {
        let email = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, email.count <= 254, !email.contains(" ") else { return false }
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        guard let dot = domain.lastIndex(of: "."), dot != domain.startIndex,
              domain.distance(from: dot, to: domain.endIndex) > 2 else { return false }
        return true
    }
}

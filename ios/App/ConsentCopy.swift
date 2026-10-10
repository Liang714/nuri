import Foundation

/// The single source for consent-screen wording. ConsentView renders only these, and ConsentCopyTests pins them to
/// AppState.consentVersion, so editing any of them (in Swift or in the catalog) forces a consent-version bump.
enum ConsentCopy {
    static let adultTitle: LocalizedStringResource = "I am 18 or older"
    static let adultDetail: LocalizedStringResource = "Nuri is made for adults."
    static let healthTitle: LocalizedStringResource = "Store my food and activity data"
    static let healthDetail: LocalizedStringResource = "Needed to run Nuri. This is health information, kept private and never sold or used to target ads. Export or delete it anytime."
    static let analyticsTitle: LocalizedStringResource = "Share anonymous usage stats"
    static let analyticsDetail: LocalizedStringResource = "Helps improve Nuri. Never includes foods, notes or health data."
    static let disclaimer: LocalizedStringResource = "Nuri gives general wellness estimates, not medical advice. Food energy, nutrients and exercise vary by person, preparation and device. For medical or nutrition guidance, talk to a qualified clinician."

    /// What the person agrees to. Pinned by ConsentCopyTests: changing any of these needs a consent-version bump.
    static let all: [LocalizedStringResource] = [adultTitle, adultDetail, healthTitle, healthDetail, analyticsTitle, analyticsDetail, disclaimer]

    // Screen chrome: titles, section headers, the link into the data-use notice, the button and its hint.
    // They name controls and say nothing about what is stored or agreed to, so they are not in `all`
    // and editing them does not change the consent a person gave.
    static let screenTitle: LocalizedStringResource = "Before you start"
    static let requiredHeader: LocalizedStringResource = "Required"
    static let optionalHeader: LocalizedStringResource = "Optional"
    static let dataUseLink: LocalizedStringResource = "What we store and why"
    static let continueButton: LocalizedStringResource = "Continue"
    static let requiredHint: LocalizedStringResource = "Turn on the two required items to continue."
}

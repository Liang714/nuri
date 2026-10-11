import Foundation
import NuriDomain
import NutritionEngine
import Persistence
import SwiftData

/// The years the profile steps work in. Always Gregorian: the person's own calendar (Japanese, Buddhist, ...) must not
/// shift the year of birth picker or the age the engines compute.
enum ProfileCalendar {
    static func currentYear(now: Date = .now) -> Int {
        Calendar(identifier: .gregorian).component(.year, from: now)
    }

    /// Adults only: from 100 years ago to 18 years ago.
    static func birthYears(currentYear: Int) -> ClosedRange<Int> {
        (currentYear - 100)...(currentYear - 18)
    }
}

extension ProfileDraft {
    /// The draft a first-time person starts from: a 30-year-old, 170 cm and 65 kg, lightly active, keeping their weight.
    /// Units and the BMI standard follow the device region. Sex is left empty on purpose: nothing is assumed.
    static func starting(regionCode: String?, currentYear: Int) -> ProfileDraft {
        ProfileDraft(
            birthYear: currentYear - 30,
            sex: nil,
            heightCm: 170,
            weightKg: 65,
            activityLevel: .lightlyActive,
            goal: .maintain,
            unitSystem: UnitSystem.defaultFor(regionCode: regionCode),
            bmiStandard: BMIStandard.defaultStandard(forRegion: regionCode)
        )
    }

    /// The draft the profile flow opens with: the saved profile when there is one, so running the flow again never replaces
    /// saved answers with defaults, and the starting values otherwise (nothing saved, or the store cannot be read).
    @MainActor
    static func opening(context: ModelContext, regionCode: String?, currentYear: Int) -> ProfileDraft {
        let saved = (try? ProfileRepository(context: context).draft()) ?? nil
        return (saved ?? .starting(regionCode: regionCode, currentYear: currentYear)).clampedForEditing(currentYear: currentYear)
    }

    /// The same draft with year of birth and height inside what the steps can show. A saved profile is always inside
    /// them; this only keeps a damaged or very old record from leaving a picker without a valid selection.
    func clampedForEditing(currentYear: Int) -> ProfileDraft {
        var copy = self
        let years = ProfileCalendar.birthYears(currentYear: currentYear)
        copy.birthYear = min(max(birthYear, years.lowerBound), years.upperBound)
        copy.heightCm = BodyInput.clampedHeightCm(heightCm)
        return copy
    }
}

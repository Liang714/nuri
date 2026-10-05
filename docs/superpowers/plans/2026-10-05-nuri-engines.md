# Nuri Calculation Engines Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure-Swift calculation core of Nuri: energy targets, BMI, nutrient and recipe math, daily ledger, MET catalog, activity equivalents, duplicate detection, and the daily movement plan. Everything is unit tested and has no UI or network.

**Architecture:** One local Swift package `ios/Packages/NuriEngines` with three library targets:
- `NuriDomain`: shared value types (profile, enums, calendar day).
- `NutritionEngine`: BMR/TDEE, targets, BMI, nutrients, servings, recipes, ledger.
- `ActivityEngine`: MET catalog, energy estimates, equivalents, duplicates, movement plan.

Engines return enums and numbers, never user-facing strings; the app localizes. Every type is a `Sendable` value type.

**Tech Stack:** Swift 6 language mode, Swift Package Manager, Swift Testing (`import Testing`), Foundation, CryptoKit. No third-party dependencies.

**Spec:** `docs/specs/2026-10-05-nuri-design.md` (sections "Daily exercise plan", "Safety"), plus `docs/original-product-spec.md` §4, §5.1, §5.4–5.6, §14.

## Global Constraints
- swift-tools-version 6.0; platforms `.iOS(.v17)`, `.macOS(.v14)` (macOS only so `swift test` runs without a simulator).
- No third-party dependencies. No `Any`/`AnyObject` in public API.
- Engines expose no user-facing strings; outcomes are enums (the app maps them to localized copy).
- Safety values copied from the spec: loss default −250 kcal/day, conservative max −500; gain default +200; activity factors 1.2 / 1.375 / 1.55 / 1.725 / 1.9; equivalents uncertainty −20% / +25%; equivalents session cap default 60 min; daily plan cap 90 min/day; progression ≤ +10%/week; BMI < 18.5 → no loss plan; readiness "yes" → clinician-clearance plan; sensitive mode → no kcal numbers and no equivalents.
- Users are 18+ (age range 18…120).
- Test command (run from repo root): `swift test --package-path ios/Packages/NuriEngines`.
- Commit after every task, ending the message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File Structure
```
ios/Packages/NuriEngines/
  Package.swift
  Sources/NuriDomain/
    BodyProfile.swift          SexForEquation, ActivityLevel, Goal, BodyProfile + validation
    ActivityEnergySource.swift shared energy-source enum
    CalendarDay.swift          timezone-safe day keys, week helper
  Sources/NutritionEngine/
    Rounding.swift             shared rounding helpers (internal + public roundTo)
    BMI.swift                  BMI value, WHO / Asian-Pacific categories
    EnergyTargets.swift        Mifflin-St Jeor, TDEE, goal adjustment, minimum-target policy
    Nutrients.swift            NutrientProfile arithmetic, energy consistency check
    Servings.swift             ServingUnit/Option, gram conversion
    Recipe.swift               recipe totals / per serving / per 100 g
    DailyLedger.swift          food vs activity vs target, exercise-credit modes
  Sources/ActivityEngine/
    Resources/met-catalog.json versioned MET catalog
    METCatalog.swift           catalog model + bundled loader + filtering
    EnergyEstimator.swift      MET × kg × h, ranges
    ActivityEquivalents.swift  opt-in equivalents (spec §5.6)
    DuplicateDetector.swift    overlap rule + fingerprints
    MovementPlan.swift         daily movement plan types
    MovementPlanner.swift      daily movement plan algorithm
  Tests/NuriDomainTests/…, Tests/NutritionEngineTests/…, Tests/ActivityEngineTests/…
.github/workflows/engines.yml
```

---

### Task 1: Package scaffold, domain types, CI

**Files:**
- Create: `ios/Packages/NuriEngines/Package.swift`
- Create: `ios/Packages/NuriEngines/Sources/NuriDomain/BodyProfile.swift`
- Create: `ios/Packages/NuriEngines/Sources/NuriDomain/ActivityEnergySource.swift`
- Create: `ios/Packages/NuriEngines/Sources/NuriDomain/CalendarDay.swift`
- Create: `ios/Packages/NuriEngines/Sources/NutritionEngine/Rounding.swift`
- Create: `ios/Packages/NuriEngines/Sources/ActivityEngine/Resources/met-catalog.json` (placeholder `{}` replaced in Task 7)
- Test: `ios/Packages/NuriEngines/Tests/NuriDomainTests/BodyProfileTests.swift`, `CalendarDayTests.swift`
- Create: `.github/workflows/engines.yml`

**Interfaces:**
- Produces: `SexForEquation {male,female}`, `ActivityLevel` (Comparable, `.factor`), `Goal`, `BodyProfile(ageYears:sex:heightCm:weightKg:activityLevel:goal:)` with `validated() throws(ProfileValidationError)`, `ActivityEnergySource {manualMET, wearable, healthPlatform, custom}`, `CalendarDay(date:timeZone:)`, `CalendarDay.daysRemainingInWeek(firstWeekday:)`, `roundTo(_:step:)`.

- [ ] **Step 1: Write Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NuriEngines",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NuriDomain", targets: ["NuriDomain"]),
        .library(name: "NutritionEngine", targets: ["NutritionEngine"]),
        .library(name: "ActivityEngine", targets: ["ActivityEngine"]),
    ],
    targets: [
        .target(name: "NuriDomain"),
        .target(name: "NutritionEngine", dependencies: ["NuriDomain"]),
        .target(
            name: "ActivityEngine",
            dependencies: ["NuriDomain", "NutritionEngine"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "NuriDomainTests", dependencies: ["NuriDomain"]),
        .testTarget(name: "NutritionEngineTests", dependencies: ["NutritionEngine", "NuriDomain"]),
        .testTarget(name: "ActivityEngineTests", dependencies: ["ActivityEngine", "NutritionEngine", "NuriDomain"]),
    ]
)
```

Also create `Sources/ActivityEngine/Resources/met-catalog.json` containing `{}`, and empty test folders `Tests/NutritionEngineTests/` and `Tests/ActivityEngineTests/`, each with a `Placeholder.swift` containing `import Testing` (deleted when real tests land in Tasks 2 and 7).

- [ ] **Step 2: Write failing domain tests**

`Tests/NuriDomainTests/BodyProfileTests.swift`:
```swift
import Testing
@testable import NuriDomain

@Suite struct BodyProfileTests {
    let valid = BodyProfile(ageYears: 30, sex: .male, heightCm: 180, weightKg: 80,
                            activityLevel: .moderatelyActive, goal: .maintain)

    @Test func activityFactorsMatchSpec() {
        #expect(ActivityLevel.sedentary.factor == 1.2)
        #expect(ActivityLevel.lightlyActive.factor == 1.375)
        #expect(ActivityLevel.moderatelyActive.factor == 1.55)
        #expect(ActivityLevel.veryActive.factor == 1.725)
        #expect(ActivityLevel.extraActive.factor == 1.9)
    }

    @Test func activityLevelsAreOrdered() {
        #expect(ActivityLevel.sedentary < .moderatelyActive)
        #expect(ActivityLevel.extraActive > .veryActive)
    }

    @Test func validProfilePasses() throws {
        #expect(try valid.validated() == valid)
    }

    @Test func under18IsRejected() {
        var p = valid; p.ageYears = 17
        #expect(throws: ProfileValidationError.ageOutOfRange(17)) { try p.validated() }
    }

    @Test func implausibleHeightAndWeightRejected() {
        var h = valid; h.heightCm = 90
        #expect(throws: ProfileValidationError.heightOutOfRange(90)) { try h.validated() }
        var w = valid; w.weightKg = 20
        #expect(throws: ProfileValidationError.weightOutOfRange(20)) { try w.validated() }
    }
}
```

`Tests/NuriDomainTests/CalendarDayTests.swift`:
```swift
import Foundation
import Testing
@testable import NuriDomain

@Suite struct CalendarDayTests {
    func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    @Test func seoulPastMidnightIsNextDay() {
        let d = CalendarDay(date: date("2026-10-05T15:30:00Z"), timeZone: TimeZone(identifier: "Asia/Seoul")!)
        #expect(d.description == "2026-10-06")
    }

    @Test func newYorkAcrossDSTStart() {
        let ny = TimeZone(identifier: "America/New_York")!
        // 23:30 EST on 2026-03-07 (before DST)
        #expect(CalendarDay(date: date("2026-03-08T04:30:00Z"), timeZone: ny).description == "2026-03-07")
        // 23:30 EDT on 2026-03-08 (DST day)
        #expect(CalendarDay(date: date("2026-03-09T03:30:00Z"), timeZone: ny).description == "2026-03-08")
    }

    @Test func ordering() {
        #expect(CalendarDay(year: 2026, month: 1, day: 31) < CalendarDay(year: 2026, month: 2, day: 1))
    }

    @Test func daysRemainingInWeek() {
        let monday = CalendarDay(year: 2026, month: 10, day: 5)
        #expect(monday.daysRemainingInWeek(firstWeekday: 2) == 7) // week starts Monday
        #expect(monday.daysRemainingInWeek(firstWeekday: 1) == 6) // week starts Sunday
        let sunday = CalendarDay(year: 2026, month: 10, day: 11)
        #expect(sunday.daysRemainingInWeek(firstWeekday: 2) == 1)
    }
}
```

- [ ] **Step 3: Run tests, verify they fail**

Run: `swift test --package-path ios/Packages/NuriEngines`
Expected: compile errors ("cannot find 'BodyProfile' in scope").

- [ ] **Step 4: Implement domain types**

`Sources/NuriDomain/BodyProfile.swift`:
```swift
/// Sex value used only by energy equations that require it (Mifflin-St Jeor). Optional for users.
public enum SexForEquation: String, Codable, Sendable, CaseIterable {
    case male, female
}

public enum ActivityLevel: String, Codable, Sendable, CaseIterable, Comparable {
    case sedentary, lightlyActive, moderatelyActive, veryActive, extraActive

    public var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .lightlyActive: 1.375
        case .moderatelyActive: 1.55
        case .veryActive: 1.725
        case .extraActive: 1.9
        }
    }

    private var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }
}

public enum Goal: String, Codable, Sendable, CaseIterable {
    case maintain, gradualLoss, gradualGain, improveNutrition, performance, trackOnly
}

public enum ProfileValidationError: Error, Equatable, Sendable {
    case ageOutOfRange(Int)
    case heightOutOfRange(Double)
    case weightOutOfRange(Double)
}

public struct BodyProfile: Codable, Sendable, Equatable {
    public static let ageRange = 18...120
    public static let heightRangeCm = 100.0...250.0
    public static let weightRangeKg = 30.0...350.0

    public var ageYears: Int
    public var sex: SexForEquation?
    public var heightCm: Double
    public var weightKg: Double
    public var activityLevel: ActivityLevel
    public var goal: Goal

    public init(ageYears: Int, sex: SexForEquation?, heightCm: Double, weightKg: Double,
                activityLevel: ActivityLevel, goal: Goal) {
        self.ageYears = ageYears
        self.sex = sex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityLevel = activityLevel
        self.goal = goal
    }

    public func validated() throws(ProfileValidationError) -> BodyProfile {
        guard Self.ageRange.contains(ageYears) else { throw .ageOutOfRange(ageYears) }
        guard Self.heightRangeCm.contains(heightCm) else { throw .heightOutOfRange(heightCm) }
        guard Self.weightRangeKg.contains(weightKg) else { throw .weightOutOfRange(weightKg) }
        return self
    }
}
```

`Sources/NuriDomain/ActivityEnergySource.swift`:
```swift
/// Where an activity energy value came from. Shown to users as a source label.
public enum ActivityEnergySource: String, Codable, Sendable, CaseIterable {
    case manualMET, wearable, healthPlatform, custom
}
```

`Sources/NuriDomain/CalendarDay.swift`:
```swift
import Foundation

/// A calendar date in the user's time zone. Diary entries are grouped by this, never by UTC date.
public struct CalendarDay: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(date: Date, timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    public var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// Days left in the week including today. `firstWeekday` uses Calendar numbering (1 = Sunday, 2 = Monday).
    public func daysRemainingInWeek(firstWeekday: Int) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        let weekday = calendar.component(.weekday, from: date)
        let offset = (weekday - firstWeekday + 7) % 7
        return 7 - offset
    }
}
```

`Sources/NutritionEngine/Rounding.swift`:
```swift
/// Rounds to the nearest multiple of `step` (half away from zero).
public func roundTo(_ value: Double, step: Double) -> Double {
    (value / step).rounded() * step
}

/// Rounds up to the next multiple of `step`.
public func ceilTo(_ value: Double, step: Double) -> Double {
    (value / step).rounded(.up) * step
}
```

`.github/workflows/engines.yml`:
```yaml
name: engines
on:
  push:
  pull_request:
jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Run engine tests
        run: swift test --package-path ios/Packages/NuriEngines
```

- [ ] **Step 5: Run tests, verify pass**

Run: `swift test --package-path ios/Packages/NuriEngines`
Expected: all NuriDomainTests pass.

- [ ] **Step 6: Commit**

```bash
git add ios .github
git commit -m "feat(engines): scaffold NuriEngines package with domain types and CI"
```

---

### Task 2: BMI with WHO and Asian-Pacific cutoffs

**Files:**
- Create: `ios/Packages/NuriEngines/Sources/NutritionEngine/BMI.swift`
- Test: `ios/Packages/NuriEngines/Tests/NutritionEngineTests/BMITests.swift` (delete `Placeholder.swift`)

**Interfaces:**
- Produces: `BMIStandard {who, asianPacific}`, `BMIStandard.defaultStandard(forRegion: String?) -> BMIStandard`, `BMICategory {underweight, normal, overweight, obese}`, `BMI.value(weightKg:heightCm:) -> Double`, `BMI.category(for:standard:) -> BMICategory`.

- [ ] **Step 1: Write failing tests**

```swift
import Testing
@testable import NutritionEngine

func approx(_ a: Double, _ b: Double, tol: Double = 0.01) -> Bool { abs(a - b) <= tol }

@Suite struct BMITests {
    @Test func value() {
        #expect(approx(BMI.value(weightKg: 70, heightCm: 175), 22.857))
    }

    @Test(arguments: [
        (70.0, 175.0, BMICategory.normal, BMICategory.normal),
        (72.0, 170.0, .normal, .overweight),      // 24.9
        (80.0, 170.0, .overweight, .obese),       // 27.7
        (95.0, 170.0, .obese, .obese),            // 32.9
        (50.0, 170.0, .underweight, .underweight) // 17.3
    ])
    func categories(weight: Double, height: Double, who: BMICategory, asian: BMICategory) {
        let bmi = BMI.value(weightKg: weight, heightCm: height)
        #expect(BMI.category(for: bmi, standard: .who) == who)
        #expect(BMI.category(for: bmi, standard: .asianPacific) == asian)
    }

    @Test func boundariesBelongToHigherCategory() {
        #expect(BMI.category(for: 18.5, standard: .who) == .normal)
        #expect(BMI.category(for: 25.0, standard: .who) == .overweight)
        #expect(BMI.category(for: 30.0, standard: .who) == .obese)
        #expect(BMI.category(for: 23.0, standard: .asianPacific) == .overweight)
        #expect(BMI.category(for: 25.0, standard: .asianPacific) == .obese)
    }

    @Test func defaultStandardByRegion() {
        #expect(BMIStandard.defaultStandard(forRegion: "KR") == .asianPacific)
        #expect(BMIStandard.defaultStandard(forRegion: "jp") == .asianPacific)
        #expect(BMIStandard.defaultStandard(forRegion: "US") == .who)
        #expect(BMIStandard.defaultStandard(forRegion: nil) == .who)
    }
}
```

- [ ] **Step 2: Run, verify fail** — `swift test --package-path ios/Packages/NuriEngines --filter BMITests` → compile error.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// WHO (2000) adult cutoffs, or WHO Western Pacific (2000) / Korean Society for the Study of Obesity cutoffs.
public enum BMIStandard: String, Codable, Sendable, CaseIterable {
    case who, asianPacific

    static let asianPacificRegions: Set<String> = [
        "KR", "JP", "CN", "TW", "HK", "MO", "SG", "MY", "TH", "VN", "PH", "ID", "MN",
    ]

    /// Default by App Store / device region; the user can override in Settings.
    public static func defaultStandard(forRegion code: String?) -> BMIStandard {
        guard let code else { return .who }
        return asianPacificRegions.contains(code.uppercased()) ? .asianPacific : .who
    }
}

public enum BMICategory: String, Codable, Sendable, CaseIterable {
    case underweight, normal, overweight, obese
}

public enum BMI {
    public static func value(weightKg: Double, heightCm: Double) -> Double {
        let m = heightCm / 100
        return weightKg / (m * m)
    }

    public static func category(for bmi: Double, standard: BMIStandard) -> BMICategory {
        if bmi < 18.5 { return .underweight }
        switch standard {
        case .who:
            if bmi < 25 { return .normal }
            return bmi < 30 ? .overweight : .obese
        case .asianPacific:
            if bmi < 23 { return .normal }
            return bmi < 25 ? .overweight : .obese
        }
    }
}
```

- [ ] **Step 4: Run, verify pass** — same command → PASS.

- [ ] **Step 5: Commit** — `git add ios && git commit -m "feat(nutrition): BMI with WHO and Asian-Pacific cutoffs"`

---

### Task 3: Energy targets (Mifflin-St Jeor, TDEE, goal adjustment, low-target policy)

**Files:**
- Create: `ios/Packages/NuriEngines/Sources/NutritionEngine/EnergyTargets.swift`
- Test: `ios/Packages/NuriEngines/Tests/NutritionEngineTests/EnergyTargetsTests.swift`

**Interfaces:**
- Consumes: `BodyProfile`, `BMI` (Task 2), `roundTo` (Task 1).
- Produces: `EnergyFormula.mifflinStJeorBMR(weightKg:heightCm:ageYears:sex:)`, `EnergyFormula.tdee(bmr:activityLevel:)`, `GoalAdjustmentPolicy.defaultAdjustment(for:)` / `.clamp(_:for:)`, `LowTargetPolicy.recommendedMinimumKcal(sex:)`, `EnergyTargetCalculator.estimate(profile:adjustmentKcal:) throws(ProfileValidationError) -> EnergyTargetEstimate?`, `EnergyTargetCalculator.assessManualTarget(_:sex:) -> ManualTargetAssessment`.

- [ ] **Step 1: Write failing tests**

```swift
import Testing
import NuriDomain
@testable import NutritionEngine

@Suite struct EnergyTargetsTests {
    let male = BodyProfile(ageYears: 30, sex: .male, heightCm: 180, weightKg: 80,
                           activityLevel: .moderatelyActive, goal: .maintain)
    let female = BodyProfile(ageYears: 28, sex: .female, heightCm: 165, weightKg: 60,
                             activityLevel: .sedentary, goal: .maintain)

    @Test func mifflinStJeorVectors() {
        #expect(EnergyFormula.mifflinStJeorBMR(weightKg: 80, heightCm: 180, ageYears: 30, sex: .male) == 1780)
        #expect(EnergyFormula.mifflinStJeorBMR(weightKg: 60, heightCm: 165, ageYears: 28, sex: .female) == 1330.25)
    }

    @Test func tdee() {
        #expect(approx(EnergyFormula.tdee(bmr: 1780, activityLevel: .moderatelyActive), 2759))
    }

    @Test func maintainTargetRoundedToTen() throws {
        let e = try #require(try EnergyTargetCalculator.estimate(profile: male))
        #expect(e.targetKcal == 2760)
        #expect(e.adjustmentKcal == 0)
        #expect(e.method == "mifflin_st_jeor_1990")
        #expect(!e.raisedToMinimum)
    }

    @Test func gradualLossDefaultIsMinus250() throws {
        var p = male; p.goal = .gradualLoss
        let e = try #require(try EnergyTargetCalculator.estimate(profile: p))
        #expect(e.adjustmentKcal == -250)
        #expect(e.targetKcal == 2510)
    }

    @Test func lossIsClampedToConservativeMax() throws {
        var p = male; p.goal = .gradualLoss
        let e = try #require(try EnergyTargetCalculator.estimate(profile: p, adjustmentKcal: -1000))
        #expect(e.adjustmentKcal == -500)
    }

    @Test func gradualGainDefaultIsPlus200() throws {
        var p = male; p.goal = .gradualGain
        let e = try #require(try EnergyTargetCalculator.estimate(profile: p))
        #expect(e.adjustmentKcal == 200)
    }

    @Test func calculatedTargetNeverBelowRecommendedMinimum() throws {
        var p = female; p.goal = .gradualLoss
        let e = try #require(try EnergyTargetCalculator.estimate(profile: p, adjustmentKcal: -500))
        #expect(e.targetKcal == 1200)
        #expect(e.raisedToMinimum)
    }

    @Test func lossNotAppliedWhenUnderweight() throws {
        let p = BodyProfile(ageYears: 25, sex: .female, heightCm: 170, weightKg: 50,
                            activityLevel: .lightlyActive, goal: .gradualLoss)
        let e = try #require(try EnergyTargetCalculator.estimate(profile: p))
        #expect(e.adjustmentKcal == 0)
        #expect(e.lossNotAppliedUnderweight)
    }

    @Test func noSexMeansManualSetup() throws {
        var p = male; p.sex = nil
        #expect(try EnergyTargetCalculator.estimate(profile: p) == nil)
    }

    @Test func invalidProfileThrows() {
        var p = male; p.ageYears = 16
        #expect(throws: ProfileValidationError.ageOutOfRange(16)) {
            try EnergyTargetCalculator.estimate(profile: p)
        }
    }

    @Test func manualTargetAssessmentWarnsButDoesNotBlock() {
        #expect(EnergyTargetCalculator.assessManualTarget(1100, sex: .female) == .belowRecommendedMinimum(minimumKcal: 1200))
        #expect(EnergyTargetCalculator.assessManualTarget(1400, sex: .male) == .belowRecommendedMinimum(minimumKcal: 1500))
        #expect(EnergyTargetCalculator.assessManualTarget(2000, sex: nil) == .ok)
        #expect(EnergyTargetCalculator.assessManualTarget(0, sex: .male) == .invalid)
        #expect(EnergyTargetCalculator.assessManualTarget(20000, sex: .male) == .invalid)
    }
}
```

- [ ] **Step 2: Run, verify fail** — `--filter EnergyTargetsTests` → compile error.

- [ ] **Step 3: Implement**

```swift
import NuriDomain

public enum EnergyFormula {
    /// Mifflin MD, St Jeor ST, et al. Am J Clin Nutr. 1990;51(2):241-7.
    public static func mifflinStJeorBMR(weightKg: Double, heightCm: Double, ageYears: Int,
                                        sex: SexForEquation) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(ageYears)
        return sex == .male ? base + 5 : base - 161
    }

    public static func tdee(bmr: Double, activityLevel: ActivityLevel) -> Double {
        bmr * activityLevel.factor
    }
}

public enum GoalAdjustmentPolicy {
    public static let defaultLossKcal = 250.0
    public static let maxLossKcal = 500.0
    public static let defaultGainKcal = 200.0
    public static let maxGainKcal = 500.0

    public static func defaultAdjustment(for goal: Goal) -> Double {
        switch goal {
        case .gradualLoss: -defaultLossKcal
        case .gradualGain: defaultGainKcal
        default: 0
        }
    }

    public static func clamp(_ adjustment: Double, for goal: Goal) -> Double {
        switch goal {
        case .gradualLoss: min(0, max(-maxLossKcal, adjustment))
        case .gradualGain: max(0, min(maxGainKcal, adjustment))
        default: 0
        }
    }
}

/// Commonly cited minimum intake for unsupervised plans. Used to raise calculated targets
/// and to show a non-blocking "consider a registered dietitian" notice for manual targets.
public enum LowTargetPolicy {
    public static func recommendedMinimumKcal(sex: SexForEquation?) -> Double {
        sex == .male ? 1500 : 1200
    }
}

public struct EnergyTargetEstimate: Equatable, Sendable {
    public let bmrKcal: Double
    public let tdeeKcal: Double
    public let adjustmentKcal: Double
    public let targetKcal: Double
    public let raisedToMinimum: Bool
    public let lossNotAppliedUnderweight: Bool
    public let method: String
}

public enum ManualTargetAssessment: Equatable, Sendable {
    case ok
    case belowRecommendedMinimum(minimumKcal: Double)
    case invalid
}

public enum EnergyTargetCalculator {
    /// Returns nil when no sex value is provided: the app offers manual target setup instead of assuming.
    public static func estimate(profile: BodyProfile,
                                adjustmentKcal: Double? = nil) throws(ProfileValidationError) -> EnergyTargetEstimate? {
        let p = try profile.validated()
        guard let sex = p.sex else { return nil }

        let bmr = EnergyFormula.mifflinStJeorBMR(weightKg: p.weightKg, heightCm: p.heightCm,
                                                 ageYears: p.ageYears, sex: sex)
        let tdee = EnergyFormula.tdee(bmr: bmr, activityLevel: p.activityLevel)

        let underweight = BMI.value(weightKg: p.weightKg, heightCm: p.heightCm) < 18.5
        let lossBlocked = p.goal == .gradualLoss && underweight
        let requested = adjustmentKcal ?? GoalAdjustmentPolicy.defaultAdjustment(for: p.goal)
        let adjustment = lossBlocked ? 0 : GoalAdjustmentPolicy.clamp(requested, for: p.goal)

        let minimum = LowTargetPolicy.recommendedMinimumKcal(sex: sex)
        let raw = tdee + adjustment
        return EnergyTargetEstimate(
            bmrKcal: bmr,
            tdeeKcal: tdee,
            adjustmentKcal: adjustment,
            targetKcal: roundTo(max(raw, minimum), step: 10),
            raisedToMinimum: raw < minimum,
            lossNotAppliedUnderweight: lossBlocked,
            method: "mifflin_st_jeor_1990"
        )
    }

    public static func assessManualTarget(_ kcal: Double, sex: SexForEquation?) -> ManualTargetAssessment {
        guard kcal.isFinite, kcal > 0, kcal <= 10_000 else { return .invalid }
        let minimum = LowTargetPolicy.recommendedMinimumKcal(sex: sex)
        return kcal < minimum ? .belowRecommendedMinimum(minimumKcal: minimum) : .ok
    }
}
```

- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat(nutrition): Mifflin-St Jeor targets with goal clamps and low-target policy"`

---

### Task 4: Nutrient arithmetic, serving conversion, energy consistency

**Files:**
- Create: `Sources/NutritionEngine/Nutrients.swift`, `Sources/NutritionEngine/Servings.swift`
- Test: `Tests/NutritionEngineTests/NutrientsTests.swift`, `Tests/NutritionEngineTests/ServingsTests.swift`

**Interfaces:**
- Produces: `NutrientProfile` (`energyKcal`, optional `proteinG carbsG fatG fiberG sugarG saturatedFatG sodiumMg`, `micronutrients: [String: Double]`, `.zero`, `scaled(by:)`, `+`), `NutritionMath.nutrients(per100g:grams:)`, `EnergyConsistency.check(_:) -> EnergyConsistency.Result`, `ServingUnit`, `ServingOption(id:unit:label:gramsPerUnit:)`, `ServingConverter.grams(quantity:unit:options:) throws(ServingConversionError) -> Double`.

- [ ] **Step 1: Write failing tests**

`NutrientsTests.swift`:
```swift
import Testing
@testable import NutritionEngine

@Suite struct NutrientsTests {
    let egg = NutrientProfile(energyKcal: 143, proteinG: 12.6, carbsG: 0.7, fatG: 9.5, sodiumMg: 142)

    @Test func scalingKeepsMissingFieldsMissing() {
        let half = egg.scaled(by: 0.5)
        #expect(half.energyKcal == 71.5)
        #expect(half.proteinG == 6.3)
        #expect(half.fiberG == nil)
    }

    @Test func addingTreatsMissingAsUnknownOnlyWhenBothMissing() {
        let toast = NutrientProfile(energyKcal: 80, proteinG: 3, carbsG: 14, fatG: 1, fiberG: 2)
        let sum = egg + toast
        #expect(sum.energyKcal == 223)
        #expect(approx(sum.proteinG!, 15.6))
        #expect(sum.fiberG == 2)
        #expect(sum.sugarG == nil)
    }

    @Test func micronutrientsMerge() {
        let a = NutrientProfile(energyKcal: 0, micronutrients: ["iron_mg": 1, "calcium_mg": 10])
        let b = NutrientProfile(energyKcal: 0, micronutrients: ["iron_mg": 2])
        #expect((a + b).micronutrients == ["iron_mg": 3, "calcium_mg": 10])
    }

    @Test func per100gToGrams() {
        let n = NutritionMath.nutrients(per100g: egg, grams: 50)
        #expect(n.energyKcal == 71.5)
    }

    @Test func energyConsistency() {
        #expect(EnergyConsistency.check(egg) == .consistent)
        let wrong = NutrientProfile(energyKcal: 500, proteinG: 10, carbsG: 10, fatG: 1)
        #expect(EnergyConsistency.check(wrong) == .inconsistent(statedKcal: 500, computedKcal: 89))
        #expect(EnergyConsistency.check(NutrientProfile(energyKcal: 100)) == .insufficientData)
    }
}
```

`ServingsTests.swift`:
```swift
import Testing
@testable import NutritionEngine

@Suite struct ServingsTests {
    let options = [
        ServingOption(id: "slice", unit: .slice, label: nil, gramsPerUnit: 32),
        ServingOption(id: "cup", unit: .cup, label: nil, gramsPerUnit: 158),
        ServingOption(id: "pkg", unit: .package, label: "1 pack (210 g)", gramsPerUnit: 210),
    ]

    @Test func massUnitsNeedNoOptions() throws {
        #expect(try ServingConverter.grams(quantity: 150, unit: .gram, options: []) == 150)
        #expect(approx(try ServingConverter.grams(quantity: 2, unit: .ounce, options: []), 56.699))
    }

    @Test func foodSpecificUnitsUseOptions() throws {
        #expect(try ServingConverter.grams(quantity: 2, unit: .slice, options: options) == 64)
        #expect(try ServingConverter.grams(quantity: 0.5, unit: .cup, options: options) == 79)
        #expect(try ServingConverter.grams(quantity: 1, unit: .package, options: options) == 210)
    }

    @Test func volumeWithoutGramWeightIsAnError() {
        #expect(throws: ServingConversionError.missingGramWeight(.milliliter)) {
            try ServingConverter.grams(quantity: 200, unit: .milliliter, options: options)
        }
    }

    @Test func nonPositiveQuantityIsAnError() {
        #expect(throws: ServingConversionError.nonPositiveQuantity) {
            try ServingConverter.grams(quantity: 0, unit: .gram, options: [])
        }
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement**

`Nutrients.swift`:
```swift
public struct NutrientProfile: Codable, Sendable, Equatable {
    public var energyKcal: Double
    public var proteinG: Double?
    public var carbsG: Double?
    public var fatG: Double?
    public var fiberG: Double?
    public var sugarG: Double?
    public var saturatedFatG: Double?
    public var sodiumMg: Double?
    /// Optional micronutrients keyed by "<name>_<unit>", e.g. "iron_mg", "vitamin_d_ug".
    public var micronutrients: [String: Double]

    public init(energyKcal: Double, proteinG: Double? = nil, carbsG: Double? = nil, fatG: Double? = nil,
                fiberG: Double? = nil, sugarG: Double? = nil, saturatedFatG: Double? = nil,
                sodiumMg: Double? = nil, micronutrients: [String: Double] = [:]) {
        self.energyKcal = energyKcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.sugarG = sugarG
        self.saturatedFatG = saturatedFatG
        self.sodiumMg = sodiumMg
        self.micronutrients = micronutrients
    }

    public static let zero = NutrientProfile(energyKcal: 0)

    public func scaled(by factor: Double) -> NutrientProfile {
        NutrientProfile(
            energyKcal: energyKcal * factor,
            proteinG: proteinG.map { $0 * factor },
            carbsG: carbsG.map { $0 * factor },
            fatG: fatG.map { $0 * factor },
            fiberG: fiberG.map { $0 * factor },
            sugarG: sugarG.map { $0 * factor },
            saturatedFatG: saturatedFatG.map { $0 * factor },
            sodiumMg: sodiumMg.map { $0 * factor },
            micronutrients: micronutrients.mapValues { $0 * factor }
        )
    }

    public static func + (lhs: NutrientProfile, rhs: NutrientProfile) -> NutrientProfile {
        func add(_ a: Double?, _ b: Double?) -> Double? {
            if a == nil && b == nil { return nil }
            return (a ?? 0) + (b ?? 0)
        }
        return NutrientProfile(
            energyKcal: lhs.energyKcal + rhs.energyKcal,
            proteinG: add(lhs.proteinG, rhs.proteinG),
            carbsG: add(lhs.carbsG, rhs.carbsG),
            fatG: add(lhs.fatG, rhs.fatG),
            fiberG: add(lhs.fiberG, rhs.fiberG),
            sugarG: add(lhs.sugarG, rhs.sugarG),
            saturatedFatG: add(lhs.saturatedFatG, rhs.saturatedFatG),
            sodiumMg: add(lhs.sodiumMg, rhs.sodiumMg),
            micronutrients: lhs.micronutrients.merging(rhs.micronutrients, uniquingKeysWith: +)
        )
    }
}

public enum NutritionMath {
    public static func nutrients(per100g: NutrientProfile, grams: Double) -> NutrientProfile {
        per100g.scaled(by: grams / 100)
    }
}

/// Flags records whose stated energy disagrees with Atwater general factors (4/4/9 kcal/g).
/// Tolerance is wide (max of 20 kcal or 20%) because labels round and fiber, alcohol and polyols differ.
public enum EnergyConsistency {
    public enum Result: Equatable, Sendable {
        case consistent
        case inconsistent(statedKcal: Double, computedKcal: Double)
        case insufficientData
    }

    public static func check(_ p: NutrientProfile) -> Result {
        guard let protein = p.proteinG, let carbs = p.carbsG, let fat = p.fatG else { return .insufficientData }
        let computed = 4 * protein + 4 * carbs + 9 * fat
        let tolerance = max(20, 0.2 * max(p.energyKcal, computed))
        return abs(p.energyKcal - computed) <= tolerance
            ? .consistent
            : .inconsistent(statedKcal: p.energyKcal, computedKcal: computed)
    }
}
```

`Servings.swift`:
```swift
public enum ServingUnit: String, Codable, Sendable, CaseIterable {
    case gram, ounce, milliliter, cup, tablespoon, teaspoon, piece, slice, package, serving
}

/// A food-specific serving with its gram weight. Volume units always need one (no assumed density).
public struct ServingOption: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let unit: ServingUnit
    public let label: String?
    public let gramsPerUnit: Double

    public init(id: String, unit: ServingUnit, label: String?, gramsPerUnit: Double) {
        self.id = id
        self.unit = unit
        self.label = label
        self.gramsPerUnit = gramsPerUnit
    }
}

public enum ServingConversionError: Error, Equatable, Sendable {
    case nonPositiveQuantity
    case missingGramWeight(ServingUnit)
}

public enum ServingConverter {
    public static let gramsPerOunce = 28.349523125

    public static func grams(quantity: Double, unit: ServingUnit,
                             options: [ServingOption]) throws(ServingConversionError) -> Double {
        guard quantity.isFinite, quantity > 0 else { throw .nonPositiveQuantity }
        switch unit {
        case .gram:
            return quantity
        case .ounce:
            return quantity * gramsPerOunce
        default:
            guard let option = options.first(where: { $0.unit == unit }) else { throw .missingGramWeight(unit) }
            return quantity * option.gramsPerUnit
        }
    }
}
```

- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat(nutrition): nutrient arithmetic, serving conversion, energy consistency check"`

---

### Task 5: Recipe calculator

**Files:**
- Create: `Sources/NutritionEngine/Recipe.swift`
- Test: `Tests/NutritionEngineTests/RecipeTests.swift`

**Interfaces:**
- Consumes: `NutrientProfile`, `NutritionMath` (Task 4).
- Produces: `RecipeIngredient(nutrientsPer100g:grams:)`, `RecipeNutrition {total, perServing, per100g, totalGrams}`, `RecipeCalculator.nutrition(ingredients:servings:cookedYieldGrams:) throws(RecipeError)`.

- [ ] **Step 1: Write failing tests**

```swift
import Testing
@testable import NutritionEngine

@Suite struct RecipeTests {
    let rice = RecipeIngredient(nutrientsPer100g: NutrientProfile(energyKcal: 130, proteinG: 2.7, carbsG: 28, fatG: 0.3), grams: 300)
    let chicken = RecipeIngredient(nutrientsPer100g: NutrientProfile(energyKcal: 165, proteinG: 31, carbsG: 0, fatG: 3.6), grams: 200)

    @Test func totalsAndFractionalServings() throws {
        let r = try RecipeCalculator.nutrition(ingredients: [rice, chicken], servings: 2.5)
        #expect(approx(r.total.energyKcal, 720))
        #expect(approx(r.total.proteinG!, 70.1))
        #expect(approx(r.perServing.energyKcal, 288))
        #expect(r.totalGrams == 500)
        #expect(approx(r.per100g!.energyKcal, 144))
    }

    @Test func cookedYieldChangesPer100gNotTotals() throws {
        let r = try RecipeCalculator.nutrition(ingredients: [rice, chicken], servings: 2, cookedYieldGrams: 450)
        #expect(approx(r.total.energyKcal, 720))
        #expect(approx(r.per100g!.energyKcal, 160))
        #expect(r.totalGrams == 450)
    }

    @Test func invalidInputs() {
        #expect(throws: RecipeError.noIngredients) { try RecipeCalculator.nutrition(ingredients: [], servings: 1) }
        #expect(throws: RecipeError.nonPositiveServings) { try RecipeCalculator.nutrition(ingredients: [rice], servings: 0) }
        #expect(throws: RecipeError.nonPositiveYield) {
            try RecipeCalculator.nutrition(ingredients: [rice], servings: 1, cookedYieldGrams: 0)
        }
        let bad = RecipeIngredient(nutrientsPer100g: .zero, grams: -5)
        #expect(throws: RecipeError.nonPositiveIngredientGrams) { try RecipeCalculator.nutrition(ingredients: [bad], servings: 1) }
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement**

```swift
public struct RecipeIngredient: Sendable, Equatable {
    public let nutrientsPer100g: NutrientProfile
    public let grams: Double

    public init(nutrientsPer100g: NutrientProfile, grams: Double) {
        self.nutrientsPer100g = nutrientsPer100g
        self.grams = grams
    }
}

public struct RecipeNutrition: Sendable, Equatable {
    public let total: NutrientProfile
    public let perServing: NutrientProfile
    public let per100g: NutrientProfile?
    /// Cooked yield when given, otherwise the raw ingredient weight.
    public let totalGrams: Double
}

public enum RecipeError: Error, Equatable, Sendable {
    case noIngredients, nonPositiveServings, nonPositiveIngredientGrams, nonPositiveYield
}

public enum RecipeCalculator {
    public static func nutrition(ingredients: [RecipeIngredient], servings: Double,
                                 cookedYieldGrams: Double? = nil) throws(RecipeError) -> RecipeNutrition {
        guard !ingredients.isEmpty else { throw .noIngredients }
        guard servings.isFinite, servings > 0 else { throw .nonPositiveServings }
        guard ingredients.allSatisfy({ $0.grams.isFinite && $0.grams > 0 }) else { throw .nonPositiveIngredientGrams }
        if let y = cookedYieldGrams, !(y.isFinite && y > 0) { throw .nonPositiveYield }

        let total = ingredients.reduce(NutrientProfile.zero) {
            $0 + NutritionMath.nutrients(per100g: $1.nutrientsPer100g, grams: $1.grams)
        }
        let totalGrams = cookedYieldGrams ?? ingredients.reduce(0) { $0 + $1.grams }
        return RecipeNutrition(
            total: total,
            perServing: total.scaled(by: 1 / servings),
            per100g: totalGrams > 0 ? total.scaled(by: 100 / totalGrams) : nil,
            totalGrams: totalGrams
        )
    }
}
```

- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat(nutrition): recipe calculator with cooked yield and fractional servings"`

---

### Task 6: Daily ledger and exercise-credit modes

**Files:**
- Create: `Sources/NutritionEngine/DailyLedger.swift`
- Test: `Tests/NutritionEngineTests/DailyLedgerTests.swift`

**Interfaces:**
- Consumes: `ActivityEnergySource` (Task 1).
- Produces: `ExerciseCreditMode {baseTargetOnly, partialCredit(percent:), fullCredit, noEnergyMath}` (default `.baseTargetOnly`), `DailyLedger.compute(foodKcal:activityKcalBySource:baseTargetKcal:mode:) -> DailyLedger`.

- [ ] **Step 1: Write failing tests**

```swift
import Testing
import NuriDomain
@testable import NutritionEngine

@Suite struct DailyLedgerTests {
    let activity: [ActivityEnergySource: Double] = [.manualMET: 200, .wearable: 100]

    @Test func defaultModeIsBaseTargetOnly() {
        #expect(ExerciseCreditMode.default == .baseTargetOnly)
    }

    @Test func baseTargetOnlyIgnoresActivity() {
        let l = DailyLedger.compute(foodKcal: 1500, activityKcalBySource: activity, baseTargetKcal: 2000, mode: .baseTargetOnly)
        #expect(l.totalActivityKcal == 300)
        #expect(l.creditedActivityKcal == 0)
        #expect(l.adjustedTargetKcal == 2000)
        #expect(l.remainingKcal == 500)
    }

    @Test func partialCredit() {
        let l = DailyLedger.compute(foodKcal: 1500, activityKcalBySource: activity, baseTargetKcal: 2000, mode: .partialCredit(percent: 50))
        #expect(l.creditedActivityKcal == 150)
        #expect(l.remainingKcal == 650)
    }

    @Test func partialCreditPercentIsClamped() {
        let l = DailyLedger.compute(foodKcal: 0, activityKcalBySource: activity, baseTargetKcal: 2000, mode: .partialCredit(percent: 150))
        #expect(l.creditedActivityKcal == 300)
    }

    @Test func fullCredit() {
        let l = DailyLedger.compute(foodKcal: 1500, activityKcalBySource: activity, baseTargetKcal: 2000, mode: .fullCredit)
        #expect(l.remainingKcal == 800)
    }

    @Test func noEnergyMathHasNoRemaining() {
        let l = DailyLedger.compute(foodKcal: 1500, activityKcalBySource: activity, baseTargetKcal: 2000, mode: .noEnergyMath)
        #expect(l.remainingKcal == nil)
        #expect(l.adjustedTargetKcal == nil)
        #expect(l.totalActivityKcal == 300)
    }

    @Test func noTargetHasNoRemaining() {
        let l = DailyLedger.compute(foodKcal: 1500, activityKcalBySource: [:], baseTargetKcal: nil, mode: .fullCredit)
        #expect(l.remainingKcal == nil)
    }

    @Test func remainingCanBeNegativeAndIsNotClamped() {
        let l = DailyLedger.compute(foodKcal: 2300, activityKcalBySource: [:], baseTargetKcal: 2000, mode: .baseTargetOnly)
        #expect(l.remainingKcal == -300) // the app shows this neutrally, never as "over budget"
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement**

```swift
import NuriDomain

public enum ExerciseCreditMode: Codable, Sendable, Equatable {
    case baseTargetOnly
    case partialCredit(percent: Double)
    case fullCredit
    case noEnergyMath

    /// Spec §5.5: expenditure estimates are imprecise and baseline activity is already in TDEE.
    public static let `default` = ExerciseCreditMode.baseTargetOnly
}

/// The daily "ledger" is always shown as separate lines, never as a single net-calories number.
public struct DailyLedger: Equatable, Sendable {
    public let foodKcal: Double
    public let activityKcalBySource: [ActivityEnergySource: Double]
    public let totalActivityKcal: Double
    public let baseTargetKcal: Double?
    public let creditedActivityKcal: Double
    public let adjustedTargetKcal: Double?
    /// Planning amount left. Nil without a target or in `.noEnergyMath`.
    public let remainingKcal: Double?

    public static func compute(foodKcal: Double, activityKcalBySource: [ActivityEnergySource: Double],
                               baseTargetKcal: Double?, mode: ExerciseCreditMode) -> DailyLedger {
        let totalActivity = activityKcalBySource.values.reduce(0, +)
        let credited: Double = switch mode {
        case .baseTargetOnly, .noEnergyMath: 0
        case .partialCredit(let percent): totalActivity * min(100, max(0, percent)) / 100
        case .fullCredit: totalActivity
        }
        let adjusted: Double? = (mode == .noEnergyMath) ? nil : baseTargetKcal.map { $0 + credited }
        return DailyLedger(
            foodKcal: foodKcal,
            activityKcalBySource: activityKcalBySource,
            totalActivityKcal: totalActivity,
            baseTargetKcal: baseTargetKcal,
            creditedActivityKcal: credited,
            adjustedTargetKcal: adjusted,
            remainingKcal: adjusted.map { $0 - foodKcal }
        )
    }
}
```

- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat(nutrition): daily ledger with exercise-credit modes"`

---

### Task 7: MET catalog and energy estimator

**Files:**
- Modify: `Sources/ActivityEngine/Resources/met-catalog.json` (replace placeholder)
- Create: `Sources/ActivityEngine/METCatalog.swift`, `Sources/ActivityEngine/EnergyEstimator.swift`
- Test: `Tests/ActivityEngineTests/METCatalogTests.swift`, `Tests/ActivityEngineTests/EnergyEstimatorTests.swift` (delete `Placeholder.swift`)

**Interfaces:**
- Produces: `Intensity {light, moderate, vigorous}`, `ActivityCategory {aerobic, strength, balance, flexibility}`, `METValues {light?, moderate?, vigorous?}` with `value(for:)`, `ActivityType {id, category, met, equipment, tags}` with `isLowImpact`, `isSeated`, `MobilityPreference {lowImpactOnly, seatedOnly}`, `METCatalog {version, sourceReference, activities}` with `activity(id:)`, `eligible(category:equipment:mobility:requireLowImpact:)`, `METCatalog.bundled() throws`, `EnergyRange {low, estimate, high}`, `EnergyEstimator.kcal(met:weightKg:minutes:)`, `EnergyEstimator.kcalRange(met:weightKg:minutes:)`, `EnergyEstimator.lowFactor = 0.8`, `highFactor = 1.25`.

- [ ] **Step 1: Write the catalog JSON**

Values come from the Compendium of Physical Activities (Ainsworth et al. 2011; Herrmann et al. 2024). **Before release, check each value against https://pacompendium.com and record the compendium code** (tracked in spec open items).

```json
{
  "version": "nuri-met-2026.1",
  "sourceReference": "Compendium of Physical Activities (Ainsworth et al., 2011; Herrmann et al., 2024 Adult Compendium)",
  "activities": [
    { "id": "walking", "category": "aerobic", "met": { "light": 2.8, "moderate": 3.5, "vigorous": 5.0 }, "equipment": [], "tags": ["low_impact"] },
    { "id": "running", "category": "aerobic", "met": { "light": 7.0, "moderate": 8.3, "vigorous": 9.8 }, "equipment": [], "tags": ["high_impact"] },
    { "id": "cycling_outdoor", "category": "aerobic", "met": { "light": 4.0, "moderate": 6.8, "vigorous": 8.0 }, "equipment": ["bicycle"], "tags": ["low_impact"] },
    { "id": "cycling_stationary", "category": "aerobic", "met": { "light": 3.5, "moderate": 6.8, "vigorous": 8.8 }, "equipment": ["stationary_bike"], "tags": ["low_impact", "seated"] },
    { "id": "swimming", "category": "aerobic", "met": { "light": 4.8, "moderate": 5.8, "vigorous": 9.8 }, "equipment": ["pool"], "tags": ["low_impact"] },
    { "id": "elliptical", "category": "aerobic", "met": { "moderate": 5.0 }, "equipment": ["elliptical"], "tags": ["low_impact"] },
    { "id": "dancing", "category": "aerobic", "met": { "moderate": 5.0, "vigorous": 7.3 }, "equipment": [], "tags": [] },
    { "id": "strength_bodyweight", "category": "strength", "met": { "light": 2.8, "moderate": 3.8, "vigorous": 8.0 }, "equipment": [], "tags": ["low_impact"] },
    { "id": "strength_weights", "category": "strength", "met": { "light": 3.5, "moderate": 5.0, "vigorous": 6.0 }, "equipment": ["weights"], "tags": ["low_impact"] },
    { "id": "yoga", "category": "flexibility", "met": { "light": 2.5, "moderate": 3.0, "vigorous": 4.0 }, "equipment": [], "tags": ["low_impact"] },
    { "id": "tai_chi", "category": "balance", "met": { "light": 3.0 }, "equipment": [], "tags": ["low_impact"] }
  ]
}
```

- [ ] **Step 2: Write failing tests**

`METCatalogTests.swift`:
```swift
import Testing
@testable import ActivityEngine

func approx(_ a: Double, _ b: Double, tol: Double = 0.01) -> Bool { abs(a - b) <= tol }

@Suite struct METCatalogTests {
    @Test func bundledCatalogLoadsWithVersionAndSource() throws {
        let c = try METCatalog.bundled()
        #expect(c.version == "nuri-met-2026.1")
        #expect(c.sourceReference.contains("Compendium"))
        #expect(c.activity(id: "walking")?.met.value(for: .moderate) == 3.5)
        #expect(c.activity(id: "elliptical")?.met.value(for: .light) == nil)
    }

    @Test func everyActivityHasAtLeastOneMETAndUniqueId() throws {
        let c = try METCatalog.bundled()
        #expect(Set(c.activities.map(\.id)).count == c.activities.count)
        for a in c.activities {
            #expect(a.met.light != nil || a.met.moderate != nil || a.met.vigorous != nil, "\(a.id)")
        }
    }

    @Test func eligibilityRespectsEquipmentAndMobility() throws {
        let c = try METCatalog.bundled()
        let noGear = c.eligible(category: .aerobic, equipment: [], mobility: [], requireLowImpact: false).map(\.id)
        #expect(noGear.contains("walking"))
        #expect(!noGear.contains("swimming"))

        let lowImpact = c.eligible(category: .aerobic, equipment: ["pool"], mobility: [.lowImpactOnly], requireLowImpact: false).map(\.id)
        #expect(lowImpact.contains("swimming"))
        #expect(!lowImpact.contains("running"))

        let seated = c.eligible(category: .aerobic, equipment: ["stationary_bike"], mobility: [.seatedOnly], requireLowImpact: false).map(\.id)
        #expect(seated == ["cycling_stationary"])

        let obese = c.eligible(category: .aerobic, equipment: [], mobility: [], requireLowImpact: true).map(\.id)
        #expect(!obese.contains("running"))
    }
}
```

`EnergyEstimatorTests.swift`:
```swift
import Testing
@testable import ActivityEngine

@Suite struct EnergyEstimatorTests {
    @Test func metFormula() {
        #expect(approx(EnergyEstimator.kcal(met: 3.5, weightKg: 70, minutes: 30), 122.5))
    }

    @Test func rangeUsesMinus20Plus25() {
        let r = EnergyEstimator.kcalRange(met: 3.5, weightKg: 70, minutes: 30)
        #expect(approx(r.low, 98))
        #expect(approx(r.estimate, 122.5))
        #expect(approx(r.high, 153.125))
    }
}
```

- [ ] **Step 3: Run, verify fail.**

- [ ] **Step 4: Implement**

`METCatalog.swift`:
```swift
import Foundation

public enum Intensity: String, Codable, Sendable, CaseIterable {
    case light, moderate, vigorous
}

public enum ActivityCategory: String, Codable, Sendable, CaseIterable {
    case aerobic, strength, balance, flexibility
}

public enum MobilityPreference: String, Codable, Sendable, CaseIterable {
    case lowImpactOnly, seatedOnly
}

public struct METValues: Codable, Sendable, Equatable {
    public let light: Double?
    public let moderate: Double?
    public let vigorous: Double?

    public func value(for intensity: Intensity) -> Double? {
        switch intensity {
        case .light: light
        case .moderate: moderate
        case .vigorous: vigorous
        }
    }
}

public struct ActivityType: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let category: ActivityCategory
    public let met: METValues
    public let equipment: [String]
    public let tags: [String]

    public var isLowImpact: Bool { tags.contains("low_impact") }
    public var isSeated: Bool { tags.contains("seated") }
}

public enum METCatalogError: Error, Equatable, Sendable {
    case resourceMissing
}

public struct METCatalog: Codable, Sendable, Equatable {
    public let version: String
    public let sourceReference: String
    public let activities: [ActivityType]

    public init(version: String, sourceReference: String, activities: [ActivityType]) {
        self.version = version
        self.sourceReference = sourceReference
        self.activities = activities
    }

    public static func bundled() throws -> METCatalog {
        guard let url = Bundle.module.url(forResource: "met-catalog", withExtension: "json") else {
            throw METCatalogError.resourceMissing
        }
        return try JSONDecoder().decode(METCatalog.self, from: Data(contentsOf: url))
    }

    public func activity(id: String) -> ActivityType? {
        activities.first { $0.id == id }
    }

    /// Activities the user can do with their equipment and mobility profile, in catalog order.
    public func eligible(category: ActivityCategory?, equipment: Set<String>,
                         mobility: Set<MobilityPreference>, requireLowImpact: Bool) -> [ActivityType] {
        activities.filter { a in
            (category == nil || a.category == category)
                && Set(a.equipment).isSubset(of: equipment)
                && (!mobility.contains(.seatedOnly) || a.isSeated)
                && (!(mobility.contains(.lowImpactOnly) || requireLowImpact) || a.isLowImpact)
        }
    }
}
```

`EnergyEstimator.swift`:
```swift
public struct EnergyRange: Equatable, Sendable {
    public let low: Double
    public let estimate: Double
    public let high: Double
}

public enum EnergyEstimator {
    public static let lowFactor = 0.80
    public static let highFactor = 1.25

    /// kcal = MET × body mass (kg) × duration (h).
    public static func kcal(met: Double, weightKg: Double, minutes: Double) -> Double {
        met * weightKg * minutes / 60
    }

    public static func kcalRange(met: Double, weightKg: Double, minutes: Double) -> EnergyRange {
        let e = kcal(met: met, weightKg: weightKg, minutes: minutes)
        return EnergyRange(low: e * lowFactor, estimate: e, high: e * highFactor)
    }
}
```

- [ ] **Step 5: Run, verify pass.**
- [ ] **Step 6: Commit** — `git commit -m "feat(activity): versioned MET catalog and energy estimator"`

---

### Task 8: Activity equivalents (opt-in, spec §5.6)

**Files:**
- Create: `Sources/ActivityEngine/ActivityEquivalents.swift`
- Test: `Tests/ActivityEngineTests/ActivityEquivalentsTests.swift`

**Interfaces:**
- Consumes: `METCatalog`, `MobilityPreference`, `EnergyEstimator.lowFactor/highFactor` (Task 7), `roundTo` (Task 1).
- Produces: `EquivalentsInput`, `EquivalentOption {activityId, intensity, met, minutesLow, minutesHigh, highIsOpenEnded, suggestSplitting}`, `EquivalentsResult {suppressed(SuppressionReason), options([EquivalentOption])}`, `ActivityEquivalents.practicalMinutes(_:) -> (minutes: Int, openEnded: Bool)`, `ActivityEquivalents.recommend(_:catalog:) -> EquivalentsResult`.

- [ ] **Step 1: Write failing tests**

```swift
import Testing
@testable import ActivityEngine

@Suite struct ActivityEquivalentsTests {
    let catalog = try! METCatalog.bundled()

    func input(enabled: Bool = true, sensitive: Bool = false, kcal: Double = 450, weight: Double? = 70,
               preferred: [String] = [], equipment: Set<String> = ["bicycle", "pool"],
               available: Int? = nil) -> EquivalentsInput {
        EquivalentsInput(targetKcal: kcal, weightKg: weight, preferredActivityIds: preferred,
                         availableMinutes: available, equipment: equipment, mobility: [],
                         sensitiveMode: sensitive, enabled: enabled)
    }

    @Test func disabledByDefaultSuppresses() {
        #expect(ActivityEquivalents.recommend(input(enabled: false), catalog: catalog) == .suppressed(.disabled))
    }

    @Test func sensitiveModeSuppressesEvenWhenEnabled() {
        #expect(ActivityEquivalents.recommend(input(sensitive: true), catalog: catalog) == .suppressed(.sensitiveMode))
    }

    @Test func missingWeightOrInvalidTargetSuppresses() {
        #expect(ActivityEquivalents.recommend(input(weight: nil), catalog: catalog) == .suppressed(.missingWeight))
        #expect(ActivityEquivalents.recommend(input(kcal: 0), catalog: catalog) == .suppressed(.invalidTarget))
    }

    @Test func practicalRounding() {
        #expect(ActivityEquivalents.practicalMinutes(12.4) == (10, false))
        #expect(ActivityEquivalents.practicalMinutes(12.5) == (15, false))
        #expect(ActivityEquivalents.practicalMinutes(2) == (5, false))
        #expect(ActivityEquivalents.practicalMinutes(45.4) == (50, false))
        #expect(ActivityEquivalents.practicalMinutes(88) == (90, false))
        #expect(ActivityEquivalents.practicalMinutes(95) == (90, true))
    }

    @Test func rangesMatchSpecExample() throws {
        guard case .options(let options) = ActivityEquivalents.recommend(
            input(preferred: ["cycling_outdoor", "swimming", "walking"]), catalog: catalog) else {
            Issue.record("expected options"); return
        }
        let cycling = try #require(options.first { $0.activityId == "cycling_outdoor" })
        #expect(cycling.minutesLow == 50 && cycling.minutesHigh == 70 && !cycling.highIsOpenEnded)
        #expect(cycling.suggestSplitting) // 70 > 60-minute session cap
        let swim = try #require(options.first { $0.activityId == "swimming" })
        #expect(swim.minutesLow == 50 && swim.minutesHigh == 80)
        let walk = try #require(options.first { $0.activityId == "walking" })
        #expect(walk.highIsOpenEnded && walk.suggestSplitting)
        #expect(options.allSatisfy { $0.intensity != .vigorous })
    }

    @Test func preferredFirstCappedAtFiveAndIncludesWalking() {
        guard case .options(let options) = ActivityEquivalents.recommend(
            input(preferred: ["swimming"], equipment: ["bicycle", "pool", "stationary_bike", "elliptical"]),
            catalog: catalog) else {
            Issue.record("expected options"); return
        }
        #expect(options.count <= 5)
        #expect(options.first?.activityId == "swimming")
        #expect(options.contains { $0.activityId == "walking" })
    }

    @Test func smallTargetWithinSessionCapNeedsNoSplit() {
        guard case .options(let options) = ActivityEquivalents.recommend(input(kcal: 100), catalog: catalog) else {
            Issue.record("expected options"); return
        }
        #expect(options.allSatisfy { !$0.suggestSplitting })
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement**

```swift
import NutritionEngine

public struct EquivalentsInput: Sendable {
    public var targetKcal: Double
    public var weightKg: Double?
    public var preferredActivityIds: [String]
    public var availableMinutes: Int?
    public var equipment: Set<String>
    public var mobility: Set<MobilityPreference>
    public var sensitiveMode: Bool
    public var enabled: Bool
    public var maxSessionMinutes: Int

    public init(targetKcal: Double, weightKg: Double?, preferredActivityIds: [String], availableMinutes: Int?,
                equipment: Set<String>, mobility: Set<MobilityPreference>, sensitiveMode: Bool, enabled: Bool,
                maxSessionMinutes: Int = 60) {
        self.targetKcal = targetKcal
        self.weightKg = weightKg
        self.preferredActivityIds = preferredActivityIds
        self.availableMinutes = availableMinutes
        self.equipment = equipment
        self.mobility = mobility
        self.sensitiveMode = sensitiveMode
        self.enabled = enabled
        self.maxSessionMinutes = maxSessionMinutes
    }
}

public struct EquivalentOption: Equatable, Sendable {
    public let activityId: String
    public let intensity: Intensity
    public let met: Double
    public let minutesLow: Int
    public let minutesHigh: Int
    /// True when the upper bound exceeds 90 minutes; the UI shows "90+ min".
    public let highIsOpenEnded: Bool
    /// True when the range exceeds the session cap; the UI offers "split across the day".
    public let suggestSplitting: Bool
}

public enum EquivalentsResult: Equatable, Sendable {
    public enum SuppressionReason: Equatable, Sendable {
        case disabled, sensitiveMode, missingWeight, invalidTarget
    }
    case suppressed(SuppressionReason)
    case options([EquivalentOption])
}

/// Educational, opt-in estimates. Never a requirement to offset food (spec §5.6).
public enum ActivityEquivalents {
    public static let maxOptions = 5

    /// < 30 min → nearest 5 (minimum 5); 30–90 → nearest 10; > 90 → 90 and open-ended.
    public static func practicalMinutes(_ minutes: Double) -> (minutes: Int, openEnded: Bool) {
        if minutes > 90 { return (90, true) }
        if minutes < 30 { return (max(5, Int(roundTo(minutes, step: 5))), false) }
        return (Int(roundTo(minutes, step: 10)), false)
    }

    public static func recommend(_ input: EquivalentsInput, catalog: METCatalog) -> EquivalentsResult {
        guard input.enabled else { return .suppressed(.disabled) }
        guard !input.sensitiveMode else { return .suppressed(.sensitiveMode) }
        guard let weight = input.weightKg, weight > 0 else { return .suppressed(.missingWeight) }
        guard input.targetKcal.isFinite, input.targetKcal > 0, input.targetKcal <= 5000 else {
            return .suppressed(.invalidTarget)
        }

        let candidates = catalog.eligible(category: nil, equipment: input.equipment,
                                          mobility: input.mobility, requireLowImpact: false)
            .filter { $0.category == .aerobic || $0.category == .strength }

        let options: [EquivalentOption] = candidates.compactMap { activity in
            // Moderate before vigorous: use moderate, falling back to light. Vigorous is never suggested here.
            let intensity: Intensity = activity.met.moderate != nil ? .moderate : .light
            guard let met = activity.met.value(for: intensity) else { return nil }
            let minutes = input.targetKcal / (met * weight) * 60
            let low = practicalMinutes(minutes * EnergyEstimator.lowFactor)
            let high = practicalMinutes(minutes * EnergyEstimator.highFactor)
            return EquivalentOption(
                activityId: activity.id, intensity: intensity, met: met,
                minutesLow: low.minutes, minutesHigh: high.minutes, highIsOpenEnded: high.openEnded,
                suggestSplitting: high.openEnded || high.minutes > input.maxSessionMinutes
            )
        }

        func preferenceRank(_ o: EquivalentOption) -> Int {
            input.preferredActivityIds.firstIndex(of: o.activityId) ?? Int.max
        }
        func fitsTime(_ o: EquivalentOption) -> Bool {
            input.availableMinutes.map { o.minutesLow <= $0 } ?? true
        }
        let ranked = options.sorted {
            (preferenceRank($0), fitsTime($0) ? 0 : 1, $0.minutesLow, $0.activityId)
                < (preferenceRank($1), fitsTime($1) ? 0 : 1, $1.minutesLow, $1.activityId)
        }

        var top = Array(ranked.prefix(maxOptions))
        if !top.contains(where: { $0.activityId == "walking" }),
           let walking = ranked.first(where: { $0.activityId == "walking" }) {
            if top.count == maxOptions { top.removeLast() }
            top.append(walking)
        }
        return .options(top)
    }
}
```

Note: Swift tuples of up to 6 `Comparable` elements support `<`, which the sort above relies on.

- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat(activity): opt-in activity equivalents with ranges, caps and gating"`

---

### Task 9: Duplicate activity detection and fingerprints

**Files:**
- Create: `Sources/ActivityEngine/DuplicateDetector.swift`
- Test: `Tests/ActivityEngineTests/DuplicateDetectorTests.swift`

**Interfaces:**
- Consumes: `ActivityEnergySource` (Task 1).
- Produces: `ActivityRecord(id:activityTypeId:start:durationMinutes:source:externalId:)`, `DuplicatePair {firstId, secondId}`, `DuplicateDetector.overlapFraction(_:_:)`, `isLikelyDuplicate(_:_:)`, `likelyDuplicates(in:) -> [DuplicatePair]`, `fingerprint(source:externalId:start:durationMinutes:activityTypeId:) -> String`.

- [ ] **Step 1: Write failing tests**

```swift
import Foundation
import Testing
import NuriDomain
@testable import ActivityEngine

@Suite struct DuplicateDetectorTests {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    func rec(_ id: String, type: String = "walking", offsetMin: Double = 0, duration: Double = 30,
             source: ActivityEnergySource = .manualMET) -> ActivityRecord {
        ActivityRecord(id: id, activityTypeId: type, start: t0.addingTimeInterval(offsetMin * 60),
                       durationMinutes: duration, source: source, externalId: nil)
    }

    @Test func overlapAbove80PercentIsDuplicate() {
        #expect(DuplicateDetector.isLikelyDuplicate(rec("a"), rec("b", offsetMin: 5, source: .healthPlatform)))
    }

    @Test func overlapBelow80PercentIsNot() {
        #expect(!DuplicateDetector.isLikelyDuplicate(rec("a"), rec("b", offsetMin: 7)))
    }

    @Test func differentTypeOrDurationIsNot() {
        #expect(!DuplicateDetector.isLikelyDuplicate(rec("a"), rec("b", type: "running")))
        #expect(!DuplicateDetector.isLikelyDuplicate(rec("a"), rec("b", duration: 60)))
    }

    @Test func sameRecordIsNotItsOwnDuplicate() {
        #expect(!DuplicateDetector.isLikelyDuplicate(rec("a"), rec("a")))
    }

    @Test func findsPairsOnce() {
        let pairs = DuplicateDetector.likelyDuplicates(in: [rec("a"), rec("b", offsetMin: 2), rec("c", offsetMin: 300)])
        #expect(pairs == [DuplicatePair(firstId: "a", secondId: "b")])
    }

    @Test func fingerprintIsStableAndSourceSpecific() {
        let f1 = DuplicateDetector.fingerprint(source: .healthPlatform, externalId: "HK-1", start: t0, durationMinutes: 30, activityTypeId: "walking")
        let f2 = DuplicateDetector.fingerprint(source: .healthPlatform, externalId: "HK-1", start: t0, durationMinutes: 30, activityTypeId: "walking")
        let f3 = DuplicateDetector.fingerprint(source: .wearable, externalId: "HK-1", start: t0, durationMinutes: 30, activityTypeId: "walking")
        #expect(f1 == f2)
        #expect(f1 != f3)
        #expect(f1.count == 64)
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement**

```swift
import CryptoKit
import Foundation
import NuriDomain

public struct ActivityRecord: Sendable, Equatable {
    public let id: String
    public let activityTypeId: String
    public let start: Date
    public let durationMinutes: Double
    public let source: ActivityEnergySource
    public let externalId: String?

    public init(id: String, activityTypeId: String, start: Date, durationMinutes: Double,
                source: ActivityEnergySource, externalId: String?) {
        self.id = id
        self.activityTypeId = activityTypeId
        self.start = start
        self.durationMinutes = durationMinutes
        self.source = source
        self.externalId = externalId
    }

    var end: Date { start.addingTimeInterval(durationMinutes * 60) }
}

public struct DuplicatePair: Equatable, Sendable {
    public let firstId: String
    public let secondId: String
}

/// Spec §5.5: never silently double-count activity energy.
public enum DuplicateDetector {
    public static let overlapThreshold = 0.8

    /// Overlap divided by the longer duration, so it also requires similar durations.
    public static func overlapFraction(_ a: ActivityRecord, _ b: ActivityRecord) -> Double {
        let overlap = min(a.end, b.end).timeIntervalSince(max(a.start, b.start))
        let longer = max(a.durationMinutes, b.durationMinutes) * 60
        guard overlap > 0, longer > 0 else { return 0 }
        return overlap / longer
    }

    public static func isLikelyDuplicate(_ a: ActivityRecord, _ b: ActivityRecord) -> Bool {
        a.id != b.id && a.activityTypeId == b.activityTypeId && overlapFraction(a, b) > overlapThreshold
    }

    public static func likelyDuplicates(in records: [ActivityRecord]) -> [DuplicatePair] {
        let sorted = records.sorted { $0.start < $1.start }
        var pairs: [DuplicatePair] = []
        for i in sorted.indices {
            for j in sorted.indices where j > i {
                if sorted[j].start >= sorted[i].end { break }
                if isLikelyDuplicate(sorted[i], sorted[j]) {
                    pairs.append(DuplicatePair(firstId: sorted[i].id, secondId: sorted[j].id))
                }
            }
        }
        return pairs
    }

    /// Source-specific fingerprint for imported workouts (SHA-256 hex).
    public static func fingerprint(source: ActivityEnergySource, externalId: String?, start: Date,
                                   durationMinutes: Double, activityTypeId: String) -> String {
        let key = [
            source.rawValue,
            externalId ?? "",
            String(Int(start.timeIntervalSince1970)),
            String(Int(durationMinutes.rounded())),
            activityTypeId,
        ].joined(separator: "|")
        return SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
```

- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat(activity): duplicate detection and import fingerprints"`

---

### Task 10: Daily movement plan — weekly targets and progression

**Files:**
- Create: `Sources/ActivityEngine/MovementPlan.swift` (types), `Sources/ActivityEngine/MovementPlanner.swift` (weekly target functions in this task; `plan` in Task 11)
- Test: `Tests/ActivityEngineTests/MovementWeeklyTargetsTests.swift`

**Interfaces:**
- Consumes: `BodyProfile`, `Goal`, `ActivityLevel` (Task 1), `BMICategory` (Task 2), `roundTo`, `ceilTo` (Task 1), `EnergyEstimator` (Task 7).
- Produces (types): `ReadinessQuestion`, `ReadinessScreen(yesAnswers:)` with `needsClearance`, `WeeklyActivitySummary`, `MovementPlanInput`, `PlanItemKind`, `PlanItem`, `PlanNotice`, `PlanRationale`, `WeeklyTargets`, `MovementPlan`.
- Produces (functions): `MovementPlanner.weeklyAerobicGoalMinutes(goal:weightKg:primaryModerateMET:lossDeficitKcal:activityShare:) -> Int`, `MovementPlanner.startingWeeklyMinutes(for:) -> Int`, `MovementPlanner.effectiveWeeklyMinutes(goal:level:previousWeek:) -> Int`, `MovementPlanner.strengthSessionsGoal(goal:) -> Int`, `MovementPlanner.balanceSessionsGoal(ageYears:) -> Int`, constants `dailyMaxMinutes = 90`, `minimumSessionMinutes = 10`, `whoBaseWeeklyMinutes = 150`, `whoUpperWeeklyMinutes = 300`.

- [ ] **Step 1: Write failing tests**

```swift
import Testing
import NuriDomain
@testable import ActivityEngine

@Suite struct MovementWeeklyTargetsTests {
    @Test func whoBaselineForMaintain() {
        #expect(MovementPlanner.weeklyAerobicGoalMinutes(goal: .maintain, weightKg: 70, primaryModerateMET: 3.5,
                                                         lossDeficitKcal: 250, activityShare: 0.5) == 150)
    }

    @Test func lossGoalDerivesFromActivityShareAndIsBounded() {
        // 250 × 0.5 = 125 kcal/day → 30.6 min/day at 3.5 MET, 70 kg → 214 → 215 min/week
        #expect(MovementPlanner.weeklyAerobicGoalMinutes(goal: .gradualLoss, weightKg: 70, primaryModerateMET: 3.5,
                                                         lossDeficitKcal: 250, activityShare: 0.5) == 215)
        // No activity share → WHO baseline
        #expect(MovementPlanner.weeklyAerobicGoalMinutes(goal: .gradualLoss, weightKg: 70, primaryModerateMET: 3.5,
                                                         lossDeficitKcal: 250, activityShare: 0) == 150)
        // Large deficit → capped at the WHO upper value of 300
        #expect(MovementPlanner.weeklyAerobicGoalMinutes(goal: .gradualLoss, weightKg: 70, primaryModerateMET: 3.5,
                                                         lossDeficitKcal: 500, activityShare: 0.5) == 300)
        // Deficit and share inputs are clamped (≤ 500 kcal, ≤ 0.5)
        #expect(MovementPlanner.weeklyAerobicGoalMinutes(goal: .gradualLoss, weightKg: 70, primaryModerateMET: 3.5,
                                                         lossDeficitKcal: 2000, activityShare: 1) == 300)
    }

    @Test func performanceUsesUpperGuideline() {
        #expect(MovementPlanner.weeklyAerobicGoalMinutes(goal: .performance, weightKg: 70, primaryModerateMET: 3.5,
                                                         lossDeficitKcal: 250, activityShare: 0.5) == 300)
    }

    @Test func progressionStartsLowAndGrowsAtMost10Percent() {
        #expect(MovementPlanner.startingWeeklyMinutes(for: .sedentary) == 60)
        #expect(MovementPlanner.startingWeeklyMinutes(for: .lightlyActive) == 90)
        #expect(MovementPlanner.startingWeeklyMinutes(for: .moderatelyActive) == 150)
        #expect(MovementPlanner.effectiveWeeklyMinutes(goal: 150, level: .sedentary, previousWeek: nil) == 60)
        #expect(MovementPlanner.effectiveWeeklyMinutes(goal: 150, level: .sedentary, previousWeek: 100) == 110)
        #expect(MovementPlanner.effectiveWeeklyMinutes(goal: 150, level: .sedentary, previousWeek: 200) == 150)
        #expect(MovementPlanner.effectiveWeeklyMinutes(goal: 215, level: .moderatelyActive, previousWeek: nil) == 150)
        #expect(MovementPlanner.effectiveWeeklyMinutes(goal: 215, level: .moderatelyActive, previousWeek: 200) == 215)
    }

    @Test func strengthAndBalanceGoals() {
        #expect(MovementPlanner.strengthSessionsGoal(goal: .maintain) == 2)
        #expect(MovementPlanner.strengthSessionsGoal(goal: .gradualGain) == 3)
        #expect(MovementPlanner.strengthSessionsGoal(goal: .performance) == 3)
        #expect(MovementPlanner.balanceSessionsGoal(ageYears: 64) == 0)
        #expect(MovementPlanner.balanceSessionsGoal(ageYears: 65) == 3)
    }

    @Test func readinessScreen() {
        #expect(!ReadinessScreen(yesAnswers: []).needsClearance)
        #expect(ReadinessScreen(yesAnswers: [.pregnancy]).needsClearance)
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement types**

`MovementPlan.swift`:
```swift
import NuriDomain
import NutritionEngine

/// Simplified pre-activity readiness screen (adapted from PAR-Q+). Any "yes" → clinician clearance first.
public enum ReadinessQuestion: String, Codable, Sendable, CaseIterable {
    case heartCondition, chestPainDuringActivity, dizzinessOrFainting, boneOrJointProblem,
         bloodPressureMedication, pregnancy, otherMedicalReason
}

public struct ReadinessScreen: Codable, Sendable, Equatable {
    public var yesAnswers: Set<ReadinessQuestion>
    public init(yesAnswers: Set<ReadinessQuestion>) { self.yesAnswers = yesAnswers }
    public var needsClearance: Bool { !yesAnswers.isEmpty }
}

public struct WeeklyActivitySummary: Sendable, Equatable {
    /// Moderate-equivalent minutes so far this week (1 vigorous minute counts as 2, per WHO).
    public var moderateEquivalentMinutes: Double
    public var strengthSessions: Int
    public var balanceSessions: Int
    public var didStrengthYesterday: Bool
    /// Nil when there is no history yet.
    public var previousWeekModerateEquivalentMinutes: Double?

    public init(moderateEquivalentMinutes: Double = 0, strengthSessions: Int = 0, balanceSessions: Int = 0,
                didStrengthYesterday: Bool = false, previousWeekModerateEquivalentMinutes: Double? = nil) {
        self.moderateEquivalentMinutes = moderateEquivalentMinutes
        self.strengthSessions = strengthSessions
        self.balanceSessions = balanceSessions
        self.didStrengthYesterday = didStrengthYesterday
        self.previousWeekModerateEquivalentMinutes = previousWeekModerateEquivalentMinutes
    }
}

public struct MovementPlanInput: Sendable {
    public var profile: BodyProfile
    public var bmiStandard: BMIStandard
    public var readiness: ReadinessScreen
    public var preferredActivityIds: [String]
    public var equipment: Set<String>
    public var mobility: Set<MobilityPreference>
    public var availableMinutesToday: Int?
    public var week: WeeklyActivitySummary
    public var daysRemainingInWeekIncludingToday: Int
    /// Total daily deficit for gradual loss (clamped to 0…500 kcal).
    public var lossDeficitKcal: Double
    /// Part of that deficit planned through activity (clamped to 0…0.5); the rest comes from the food target.
    public var activityShareOfDeficit: Double
    public var sensitiveMode: Bool

    public init(profile: BodyProfile, bmiStandard: BMIStandard, readiness: ReadinessScreen = .init(yesAnswers: []),
                preferredActivityIds: [String] = [], equipment: Set<String> = [], mobility: Set<MobilityPreference> = [],
                availableMinutesToday: Int? = nil, week: WeeklyActivitySummary = .init(),
                daysRemainingInWeekIncludingToday: Int = 7, lossDeficitKcal: Double = 250,
                activityShareOfDeficit: Double = 0.5, sensitiveMode: Bool = false) {
        self.profile = profile
        self.bmiStandard = bmiStandard
        self.readiness = readiness
        self.preferredActivityIds = preferredActivityIds
        self.equipment = equipment
        self.mobility = mobility
        self.availableMinutesToday = availableMinutesToday
        self.week = week
        self.daysRemainingInWeekIncludingToday = daysRemainingInWeekIncludingToday
        self.lossDeficitKcal = lossDeficitKcal
        self.activityShareOfDeficit = activityShareOfDeficit
        self.sensitiveMode = sensitiveMode
    }
}

public enum PlanItemKind: String, Sendable { case aerobic, strength, balance }

public struct PlanItem: Equatable, Sendable {
    public let kind: PlanItemKind
    public let activityId: String
    public let intensity: Intensity
    public let met: Double
    public let minutesLow: Int
    public let minutesHigh: Int
    /// Nil in sensitive mode or clearance plans.
    public let kcal: EnergyRange?
}

public enum PlanNotice: String, Sendable {
    case clinicianClearanceRecommended, underweightNoLossPlan, cappedAtDailyMaximum,
         limitedByAvailableTime, weeklyGoalReached, progressingGradually, lowImpactSelected
}

/// Evidence shown in the "why this plan" drawer.
public enum PlanRationale: String, Sendable {
    case whoPhysicalActivity2020, acsmWeightManagement2009, metCompendium, progressionTenPercent
}

public struct WeeklyTargets: Equatable, Sendable {
    public let goalMinutes: Int
    public let thisWeekMinutes: Int
    public let strengthSessions: Int
    public let balanceSessions: Int
}

public struct MovementPlan: Equatable, Sendable {
    public let items: [PlanItem]
    public let weekly: WeeklyTargets
    public let notices: [PlanNotice]
    public let rationale: [PlanRationale]
}
```

- [ ] **Step 4: Implement weekly target functions**

`MovementPlanner.swift`:
```swift
import NuriDomain
import NutritionEngine

public enum MovementPlanner {
    public static let dailyMaxMinutes = 90
    public static let minimumSessionMinutes = 10
    public static let whoBaseWeeklyMinutes = 150
    public static let whoUpperWeeklyMinutes = 300

    /// WHO 2020: 150–300 min/week moderate. For gradual loss, the activity share of the deficit
    /// sets the weekly minutes (ACSM 2009: 150–250+ min/week), bounded to 150…300.
    public static func weeklyAerobicGoalMinutes(goal: Goal, weightKg: Double, primaryModerateMET: Double,
                                                lossDeficitKcal: Double, activityShare: Double) -> Int {
        switch goal {
        case .performance:
            return whoUpperWeeklyMinutes
        case .gradualLoss:
            let deficit = min(500, max(0, lossDeficitKcal))
            let share = min(0.5, max(0, activityShare))
            let dailyKcal = deficit * share
            let dailyMinutes = dailyKcal / (primaryModerateMET * weightKg) * 60
            let weekly = roundTo(dailyMinutes * 7, step: 5)
            return Int(min(Double(whoUpperWeeklyMinutes), max(Double(whoBaseWeeklyMinutes), weekly)))
        default:
            return whoBaseWeeklyMinutes
        }
    }

    public static func startingWeeklyMinutes(for level: ActivityLevel) -> Int {
        switch level {
        case .sedentary: 60
        case .lightlyActive: 90
        default: whoBaseWeeklyMinutes
        }
    }

    /// Ramp toward the goal, increasing at most 10% over last week.
    public static func effectiveWeeklyMinutes(goal: Int, level: ActivityLevel, previousWeek: Double?) -> Int {
        let start = Double(startingWeeklyMinutes(for: level))
        let ramp = previousWeek.map { max(start, roundTo($0 * 1.10, step: 5)) } ?? start
        return Int(min(Double(goal), ramp))
    }

    public static func strengthSessionsGoal(goal: Goal) -> Int {
        goal == .gradualGain || goal == .performance ? 3 : 2
    }

    /// WHO 2020: adults 65+ add multicomponent balance activity ≥ 3 days/week.
    public static func balanceSessionsGoal(ageYears: Int) -> Int {
        ageYears >= 65 ? 3 : 0
    }
}
```

- [ ] **Step 5: Run, verify pass.**
- [ ] **Step 6: Commit** — `git commit -m "feat(activity): movement plan types, weekly targets and progression"`

---

### Task 11: Daily movement plan — today's prescription and safety gates

**Files:**
- Modify: `Sources/ActivityEngine/MovementPlanner.swift` (add `plan` and private helpers)
- Test: `Tests/ActivityEngineTests/MovementPlannerTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 2, 7, 10.
- Produces: `MovementPlanner.plan(_ input: MovementPlanInput, catalog: METCatalog) -> MovementPlan`.

Rules (from the spec):
1. Readiness "yes" → one light walking item (or light stationary cycling for seated-only users with a bike), 10–20 min, no kcal, notice `clinicianClearanceRecommended`; nothing else.
2. Underweight + gradual loss → treated as maintain, notice `underweightNoLossPlan`.
3. Obese BMI (by the selected standard) → low-impact activities only, notice `lowImpactSelected`.
4. Vigorous only when activity level ≥ moderately active, BMI not obese, and goal is performance. Vigorous minutes (MET ≥ 6) count double, so prescribed minutes are halved.
5. Today's aerobic minutes = remaining weekly minutes ÷ days left, rounded up to 5, at least 10, at most 90 (notice `cappedAtDailyMaximum`), and at most the available minutes (notice `limitedByAvailableTime`). Displayed range = ±10%, rounded to 5.
6. Strength when sessions remain and (remaining ≥ days left, or none yesterday), 15–25 min, only if ≥ 15 available minutes remain.
7. Balance (65+) when sessions remain, `tai_chi` 10–15 min light, unless seated-only.
8. Sensitive mode → `kcal` is nil everywhere.

- [ ] **Step 1: Write failing tests**

```swift
import Testing
import NuriDomain
import NutritionEngine
@testable import ActivityEngine

@Suite struct MovementPlannerTests {
    let catalog = try! METCatalog.bundled()
    let base = BodyProfile(ageYears: 30, sex: .male, heightCm: 180, weightKg: 80,
                           activityLevel: .moderatelyActive, goal: .maintain)

    func plan(_ edit: (inout MovementPlanInput) -> Void = { _ in }) -> MovementPlan {
        var input = MovementPlanInput(profile: base, bmiStandard: .who)
        edit(&input)
        return MovementPlanner.plan(input, catalog: catalog)
    }

    func aerobic(_ p: MovementPlan) -> PlanItem? { p.items.first { $0.kind == .aerobic } }

    @Test func baselinePlan() throws {
        let p = plan()
        #expect(p.weekly.goalMinutes == 150 && p.weekly.thisWeekMinutes == 150)
        let a = try #require(aerobic(p))
        #expect(a.activityId == "walking" && a.intensity == .moderate)
        #expect(a.minutesLow == 25 && a.minutesHigh == 30) // 150/7 = 21.4 → 25
        let kcal = try #require(a.kcal)
        #expect(approx(kcal.estimate, 3.5 * 80 * 25 / 60))
        #expect(p.items.contains { $0.kind == .strength && $0.activityId == "strength_bodyweight" })
        #expect(p.rationale.contains(.whoPhysicalActivity2020))
    }

    @Test func sedentaryBeginnerProgressesGradually() throws {
        let p = plan { $0.profile.activityLevel = .sedentary }
        #expect(p.weekly.thisWeekMinutes == 60)
        #expect(aerobic(p)?.minutesLow == 10)
        #expect(p.notices.contains(.progressingGradually))
        #expect(p.rationale.contains(.progressionTenPercent))
    }

    @Test func readinessYesGivesClearancePlanOnly() throws {
        let p = plan { $0.readiness = ReadinessScreen(yesAnswers: [.heartCondition]) }
        #expect(p.items.count == 1)
        let a = try #require(p.items.first)
        #expect(a.activityId == "walking" && a.intensity == .light)
        #expect(a.minutesLow == 10 && a.minutesHigh == 20 && a.kcal == nil)
        #expect(p.notices == [.clinicianClearanceRecommended])
    }

    @Test func underweightNeverGetsLossPlan() {
        let p = plan {
            $0.profile = BodyProfile(ageYears: 25, sex: .female, heightCm: 170, weightKg: 45,
                                     activityLevel: .moderatelyActive, goal: .gradualLoss)
        }
        #expect(p.notices.contains(.underweightNoLossPlan))
        #expect(p.weekly.goalMinutes == 150)
        #expect(!p.rationale.contains(.acsmWeightManagement2009))
    }

    @Test func lossPlanUsesActivityShare() {
        let p = plan {
            $0.profile.weightKg = 70
            $0.profile.goal = .gradualLoss
            $0.week.previousWeekModerateEquivalentMinutes = 200
        }
        #expect(p.weekly.goalMinutes == 215)
        #expect(p.weekly.thisWeekMinutes == 215)
        #expect(p.rationale.contains(.acsmWeightManagement2009))
    }

    @Test func sensitiveModeHidesAllKcal() {
        let p = plan { $0.sensitiveMode = true }
        #expect(!p.items.isEmpty)
        #expect(p.items.allSatisfy { $0.kcal == nil })
        #expect(!p.rationale.contains(.metCompendium))
    }

    @Test func dailyCapIs90Minutes() throws {
        let p = plan {
            $0.daysRemainingInWeekIncludingToday = 1
            $0.week.previousWeekModerateEquivalentMinutes = 300
        }
        let a = try #require(aerobic(p))
        #expect(a.minutesHigh <= MovementPlanner.dailyMaxMinutes)
        #expect(p.notices.contains(.cappedAtDailyMaximum))
    }

    @Test func availableTimeLimitsPlanAndSkipsStrength() throws {
        let p = plan { $0.availableMinutesToday = 20; $0.daysRemainingInWeekIncludingToday = 2 }
        let a = try #require(aerobic(p))
        #expect(a.minutesHigh <= 20)
        #expect(p.notices.contains(.limitedByAvailableTime))
        #expect(!p.items.contains { $0.kind == .strength })
    }

    @Test func obeseBMIGetsLowImpactEvenIfRunningPreferred() throws {
        let p = plan {
            $0.profile.heightCm = 170
            $0.profile.weightKg = 80 // 27.7: obese by Asian-Pacific cutoffs
            $0.bmiStandard = .asianPacific
            $0.preferredActivityIds = ["running"]
        }
        #expect(aerobic(p)?.activityId == "walking")
        #expect(p.notices.contains(.lowImpactSelected))
    }

    @Test func weeklyGoalReachedOmitsAerobic() {
        let p = plan { $0.week.moderateEquivalentMinutes = 160 }
        #expect(aerobic(p) == nil)
        #expect(p.notices.contains(.weeklyGoalReached))
    }

    @Test func olderAdultsGetBalance() {
        let p = plan { $0.profile.ageYears = 70 }
        #expect(p.items.contains { $0.kind == .balance && $0.activityId == "tai_chi" })
    }

    @Test func performanceAllowsVigorousWithHalvedMinutes() throws {
        let p = plan {
            $0.profile.activityLevel = .veryActive
            $0.profile.goal = .performance
            $0.preferredActivityIds = ["running"]
        }
        let a = try #require(aerobic(p))
        #expect(a.activityId == "running" && a.intensity == .vigorous)
        #expect(a.minutesLow == 10 && a.minutesHigh == 15) // 25 moderate-equivalent → 12.5 vigorous
    }

    @Test func strengthSkippedRightAfterStrengthDayWhenTimeRemains() {
        let p = plan { $0.week.didStrengthYesterday = true }
        #expect(!p.items.contains { $0.kind == .strength })
    }
}
```

Add the shared `approx` helper (already defined in `METCatalogTests.swift` in the same test target; do not redefine).

- [ ] **Step 2: Run, verify fail** — `--filter MovementPlannerTests` → "type 'MovementPlanner' has no member 'plan'".

- [ ] **Step 3: Implement `plan`**

Append to `MovementPlanner.swift` inside `enum MovementPlanner`:
```swift
    public static func plan(_ input: MovementPlanInput, catalog: METCatalog) -> MovementPlan {
        let p = input.profile
        let bmi = BMI.value(weightKg: p.weightKg, heightCm: p.heightCm)
        let bmiCategory = BMI.category(for: bmi, standard: input.bmiStandard)
        let strengthGoal = strengthSessionsGoal(goal: p.goal)
        let balanceGoal = balanceSessionsGoal(ageYears: p.ageYears)

        if input.readiness.needsClearance {
            return clearancePlan(input, catalog: catalog, strengthGoal: strengthGoal, balanceGoal: balanceGoal)
        }

        var notices: [PlanNotice] = []
        var rationale: [PlanRationale] = [.whoPhysicalActivity2020]

        var goal = p.goal
        if goal == .gradualLoss && bmiCategory == .underweight {
            goal = .maintain
            notices.append(.underweightNoLossPlan)
        }

        let requireLowImpact = bmiCategory == .obese
        let allowVigorous = p.activityLevel >= .moderatelyActive && bmiCategory != .obese && goal == .performance
        let aerobicChoice = choose(.aerobic, input: input, catalog: catalog, requireLowImpact: requireLowImpact)
        if requireLowImpact, aerobicChoice != nil,
           input.preferredActivityIds.contains(where: { id in catalog.activity(id: id).map { !$0.isLowImpact } ?? false }) {
            notices.append(.lowImpactSelected)
        }

        let primaryModerateMET = aerobicChoice?.met.moderate ?? 3.5
        let weeklyGoal = weeklyAerobicGoalMinutes(goal: goal, weightKg: p.weightKg, primaryModerateMET: primaryModerateMET,
                                                  lossDeficitKcal: input.lossDeficitKcal,
                                                  activityShare: input.activityShareOfDeficit)
        if goal == .gradualLoss { rationale.append(.acsmWeightManagement2009) }
        let thisWeek = effectiveWeeklyMinutes(goal: weeklyGoal, level: p.activityLevel,
                                              previousWeek: input.week.previousWeekModerateEquivalentMinutes)
        if thisWeek < weeklyGoal {
            notices.append(.progressingGradually)
            rationale.append(.progressionTenPercent)
        }

        var items: [PlanItem] = []
        var minutesLeftToday = input.availableMinutesToday.map { Double($0) }

        let remaining = max(0, Double(thisWeek) - input.week.moderateEquivalentMinutes)
        if remaining <= 0 {
            notices.append(.weeklyGoalReached)
        } else if let activity = aerobicChoice {
            let days = Double(max(1, min(7, input.daysRemainingInWeekIncludingToday)))
            var moderateMinutes = max(Double(minimumSessionMinutes), ceilTo(remaining / days, step: 5))
            if moderateMinutes > Double(dailyMaxMinutes) {
                moderateMinutes = Double(dailyMaxMinutes)
                notices.append(.cappedAtDailyMaximum)
            }
            let intensity: Intensity = (allowVigorous && activity.met.vigorous != nil) ? .vigorous : .moderate
            let met = activity.met.value(for: intensity) ?? activity.met.light ?? primaryModerateMET
            var minutes = met >= 6 && intensity == .vigorous ? moderateMinutes / 2 : moderateMinutes
            if let available = minutesLeftToday, minutes > available {
                minutes = available
                notices.append(.limitedByAvailableTime)
            }
            if minutes > 0 {
                let item = makeItem(.aerobic, activity: activity, intensity: intensity, met: met,
                                    minutes: minutes, cap: minutesLeftToday, input: input)
                items.append(item)
                minutesLeftToday = minutesLeftToday.map { $0 - Double(item.minutesHigh) }
            }
        }

        let strengthRemaining = strengthGoal - input.week.strengthSessions
        let daysLeft = max(1, input.daysRemainingInWeekIncludingToday)
        if strengthRemaining > 0,
           strengthRemaining >= daysLeft || !input.week.didStrengthYesterday,
           (minutesLeftToday ?? .infinity) >= 15,
           let activity = choose(.strength, input: input, catalog: catalog, requireLowImpact: requireLowImpact),
           let met = activity.met.moderate {
            items.append(fixedItem(.strength, activity: activity, intensity: .moderate, met: met,
                                   low: 15, high: 25, input: input))
            minutesLeftToday = minutesLeftToday.map { $0 - 25 }
        }

        if balanceGoal - input.week.balanceSessions > 0,
           !input.mobility.contains(.seatedOnly),
           (minutesLeftToday ?? .infinity) >= 10,
           let activity = catalog.activity(id: "tai_chi"),
           let met = activity.met.light {
            items.append(fixedItem(.balance, activity: activity, intensity: .light, met: met,
                                   low: 10, high: 15, input: input))
        }

        if !input.sensitiveMode && !items.isEmpty { rationale.append(.metCompendium) }

        return MovementPlan(
            items: items,
            weekly: WeeklyTargets(goalMinutes: weeklyGoal, thisWeekMinutes: thisWeek,
                                  strengthSessions: strengthGoal, balanceSessions: balanceGoal),
            notices: notices,
            rationale: rationale
        )
    }

    // MARK: - Helpers

    private static func clearancePlan(_ input: MovementPlanInput, catalog: METCatalog,
                                      strengthGoal: Int, balanceGoal: Int) -> MovementPlan {
        let seated = input.mobility.contains(.seatedOnly)
        let activityId = seated ? "cycling_stationary" : "walking"
        var items: [PlanItem] = []
        if let activity = catalog.activity(id: activityId),
           Set(activity.equipment).isSubset(of: input.equipment),
           let met = activity.met.light {
            items.append(PlanItem(kind: .aerobic, activityId: activity.id, intensity: .light, met: met,
                                  minutesLow: 10, minutesHigh: 20, kcal: nil))
        }
        return MovementPlan(
            items: items,
            weekly: WeeklyTargets(goalMinutes: whoBaseWeeklyMinutes, thisWeekMinutes: 0,
                                  strengthSessions: strengthGoal, balanceSessions: balanceGoal),
            notices: [.clinicianClearanceRecommended],
            rationale: [.whoPhysicalActivity2020]
        )
    }

    /// Preferred eligible activity first, then walking (aerobic) / bodyweight (strength), then catalog order.
    private static func choose(_ category: ActivityCategory, input: MovementPlanInput, catalog: METCatalog,
                               requireLowImpact: Bool) -> ActivityType? {
        let eligible = catalog.eligible(category: category, equipment: input.equipment,
                                        mobility: input.mobility, requireLowImpact: requireLowImpact)
        if let preferred = input.preferredActivityIds.lazy.compactMap({ id in eligible.first { $0.id == id } }).first {
            return preferred
        }
        let fallbackId = category == .aerobic ? "walking" : "strength_bodyweight"
        return eligible.first { $0.id == fallbackId } ?? eligible.first
    }

    private static func makeItem(_ kind: PlanItemKind, activity: ActivityType, intensity: Intensity, met: Double,
                                 minutes: Double, cap: Double?, input: MovementPlanInput) -> PlanItem {
        let upper = min(Double(dailyMaxMinutes), cap ?? .infinity)
        let low = max(5, min(upper, roundTo(minutes * 0.9, step: 5)))
        let high = max(low, min(upper, roundTo(minutes * 1.1, step: 5)))
        return PlanItem(kind: kind, activityId: activity.id, intensity: intensity, met: met,
                        minutesLow: Int(low), minutesHigh: Int(high),
                        kcal: kcalRange(met: met, low: low, estimate: minutes, high: high, input: input))
    }

    private static func fixedItem(_ kind: PlanItemKind, activity: ActivityType, intensity: Intensity, met: Double,
                                  low: Int, high: Int, input: MovementPlanInput) -> PlanItem {
        PlanItem(kind: kind, activityId: activity.id, intensity: intensity, met: met,
                 minutesLow: low, minutesHigh: high,
                 kcal: kcalRange(met: met, low: Double(low), estimate: Double(low + high) / 2,
                                 high: Double(high), input: input))
    }

    private static func kcalRange(met: Double, low: Double, estimate: Double, high: Double,
                                  input: MovementPlanInput) -> EnergyRange? {
        guard !input.sensitiveMode else { return nil }
        let w = input.profile.weightKg
        return EnergyRange(
            low: EnergyEstimator.kcal(met: met, weightKg: w, minutes: low) * EnergyEstimator.lowFactor,
            estimate: EnergyEstimator.kcal(met: met, weightKg: w, minutes: estimate),
            high: EnergyEstimator.kcal(met: met, weightKg: w, minutes: high) * EnergyEstimator.highFactor
        )
    }
```

Note on `baselinePlan`: `minutes` = 25, so low = round(22.5) = 25 and high = round(27.5) = 30; `kcal.estimate` uses 25 minutes.

- [ ] **Step 4: Run all tests, verify pass**

Run: `swift test --package-path ios/Packages/NuriEngines`
Expected: every suite passes. If `dailyCapIs90Minutes` fails because `thisWeek` was progression-limited, check that the previous-week value of 300 gives a ramp of max(150, 330) = 330, clamped to the 150 goal; remaining 150 over 1 day → capped at 90.

- [ ] **Step 5: Commit** — `git commit -m "feat(activity): daily movement plan with safety gates"`

---

### Task 12: Engine README

**Files:**
- Create: `ios/Packages/NuriEngines/README.md`

- [ ] **Step 1: Write README** covering: purpose, the three targets, the test command, the evidence sources (Mifflin-St Jeor 1990; WHO 2020 physical activity guidelines; ACSM 2009 position stand on weight loss; WHO 2000 / WHO-WPRO 2000 and KSSO BMI cutoffs; Compendium of Physical Activities 2011/2024), the safety constants and where each lives, and the rule that engines return enums, not strings.

- [ ] **Step 2: Verify the full suite once more** — `swift test --package-path ios/Packages/NuriEngines` → all pass.

- [ ] **Step 3: Commit** — `git commit -m "docs(engines): README with sources and safety constants"`

---

## Follow-up plans (separate documents, written after this one ships)
1. **App shell + DesignSystem:** Xcode project, SwiftUI navigation, String Catalogs (KO/EN), design tokens, banned-word lint script, CI with `xcodebuild test`. Needs the iOS Simulator runtime.
2. **Supabase schema:** migrations, RLS policies + tests, PGroonga search. Needs the Supabase CLI + Docker.
3. **Food data pipeline:** K-FIND / 유통바코드 / USDA / OFF ETL with validation. Needs the data.go.kr, 식품안전나라 and USDA API keys.

# Nuri Local Core A: Data, Privacy Rights and Profile Onboarding

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Nuri an on-device database (SwiftData) and deliver the privacy rights the consent screen promises: a complete PIPA notice, export, delete everything, and withdraw consent. Add the profile onboarding (year of birth, optional sex for the energy formula, height and weight in metric or imperial, activity level, goal, readiness questions, Hide numbers, daily guide) so the engines get real inputs. Close the gates the app-shell review carried forward.

**Architecture:**
- A new local package `ios/Packages/NuriPersistence` (product `Persistence`) holds versioned SwiftData models, repositories, the profile→engine mapping, export builders and a data wiper. All of it is testable with `swift test` on macOS using in-memory stores.
- Domain enums that persistence needs (`FoodGroup`, `FoodSource`, `UnitSystem`) move into `NuriDomain`. The design system keeps only their colors and icons, as extensions.
- The app gains a composition root in `NuriApp`: the `ModelContainer`, `AppState` with a consent log, and the environment.
- `AppState` gains a `.profile` stage between consent and the tabs.

**Tech Stack:** Swift 6, SwiftUI, SwiftData (iOS 17+, macOS 14+), Swift Testing, XCTest UI, String Catalogs.

**Spec:** `docs/specs/2026-10-05-nuri-design.md` (Design direction; Safety). The privacy rights come from `docs/original-product-spec.md` §5.8 and §10. Review gates are in `docs/superpowers/app-shell-followups.md`.

## Global Constraints
- Everything in `docs/superpowers/plans/2026-10-08-nuri-app-shell.md` Global Constraints still holds: iOS 17, Swift 6, native controls, palette-only colors except `BrandButtonColors`, 44/52 pt, every string in `ios/App/Localizable.xcstrings` with EN + KO, `scripts/lint_copy.py` clean on both catalogs, and nothing numeric when Hide numbers is on.
- Engines stay free of SwiftData and UI. The persistence package depends on engines only, never on DesignSystem or the app.
- Store the minimum data: **year of birth**, not a birth date. Sex is optional and used only by the energy formula.
- The health readiness answers are sensitive data. They are stored only on device and listed in the notice.
- Every privacy right promised in copy must work in this plan: export, delete everything, and withdraw consent.
- The consent copy, including the data-use notice, is pinned by `ConsentCopyTests`. Any change to it bumps `AppState.consentVersion` and updates `AppState.consentCopyFingerprint`.
- Test commands:
  - `swift test --package-path ios/Packages/NuriEngines`
  - `swift test --package-path ios/Packages/NuriDesignSystem`
  - `swift test --package-path ios/Packages/NuriPersistence`
  - `xcodebuild test -project ios/Nuri.xcodeproj -scheme Nuri -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/DerivedData -parallel-testing-enabled NO`
  - `python3 scripts/lint_copy.py ios/App/Localizable.xcstrings` and `python3 scripts/lint_copy.py ios/Packages/NuriDesignSystem/Sources/DesignSystem/Resources/Localizable.xcstrings`
- Commit after every task, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File Structure
```
ios/Packages/NuriEngines/Sources/NuriDomain/FoodGroup.swift, FoodSource.swift, Units.swift   (new; moved/added domain)
ios/Packages/NuriDesignSystem/Package.swift                     (depends on ../NuriEngines)
ios/Packages/NuriDesignSystem/Sources/DesignSystem/FoodGroup+Colors.swift  (was FoodGroup.swift)
ios/Packages/NuriDesignSystem/Sources/DesignSystem/Components/SourceLabel.swift (FoodSource + icon/color extension)
ios/Packages/NuriPersistence/
  Package.swift
  Sources/Persistence/Schema.swift            versioned schema, migration plan, NuriStore.makeContainer
  Sources/Persistence/Models.swift            ProfileRecord, FoodRecord, MealEntryRecord, ActivityLogRecord, ConsentEventRecord
  Sources/Persistence/ProfileRepository.swift ProfileDraft, ProfileRepository
  Sources/Persistence/ProfileMapping.swift    ProfileRecord → BodyProfile, ReadinessScreen, DailyGuide
  Sources/Persistence/ConsentLog.swift        ConsentEvent, ConsentLogging, SwiftDataConsentLog
  Sources/Persistence/DataWiper.swift         delete everything
  Sources/Persistence/DataExport.swift        CSV/JSON builders + file writer
  Tests/PersistenceTests/…
ios/App/ConsentCopy.swift                     consent + notice strings as LocalizedStringResource (single source)
ios/App/Onboarding/Profile/ProfileFlow.swift, ProfileSteps.swift, DailyGuideStep.swift
ios/App/Tabs/YouView.swift (+ ProfileEditView.swift, DeleteDataView.swift)
```

---

### Task 1: Review gates (consent copy source of truth, audit false positive, CI and lint fixes)

**Files:**
- Create: `ios/App/ConsentCopy.swift`
- Modify: `ios/App/Onboarding/ConsentView.swift`, `ios/NuriTests/ConsentCopyTests.swift`, `ios/NuriUITests/OnboardingUITests.swift`, `ios/README.md`, `.github/workflows/ios.yml`, `scripts/lint_copy.py`, `scripts/test_lint_copy.py`, `ios/Packages/NuriDesignSystem/Sources/DesignSystem/Components/NoticeCard.swift`, `…/AdCard.swift`

**Interfaces:**
- Produces: `enum ConsentCopy`, with static `LocalizedStringResource` constants for every consent-screen string and `static let all: [LocalizedStringResource]`. `ConsentView` renders only these constants, and `ConsentCopyTests` iterates `ConsentCopy.all.map(\.key)`.

- [ ] **Step 1: Failing test.** Change `ConsentCopyTests.consentKeys` to `ConsentCopy.all.map(\.key)`. Add a test `consentViewUsesOnlyConsentCopy` that reads `ios/App/Onboarding/ConsentView.swift` from the source tree via `#filePath` (go up from `ios/NuriTests/` to `ios/App/Onboarding/ConsentView.swift`). It asserts the file contains no `Text("` string literal or `row("` call with a quoted string, so every visible string comes from `ConsentCopy`. RED: `ConsentCopy` does not exist.
- [ ] **Step 2: Implement `ConsentCopy.swift`:**
```swift
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

    static let all: [LocalizedStringResource] = [adultTitle, adultDetail, healthTitle, healthDetail, analyticsTitle, analyticsDetail, disclaimer]
}
```
In `ConsentView`, render these with `Text(ConsentCopy.adultTitle)` and so on (`Text(_ resource: LocalizedStringResource)` is iOS 16+). The `row(_:_:)` helper takes `LocalizedStringResource`. The fingerprint does not change, because keys and values are unchanged. Run the tests, then **edit one ConsentCopy literal temporarily** and confirm `ConsentCopyTests` fails with the "not in the en strings" message. Revert, and paste that verbatim output in the report.
- [ ] **Step 3: Audit false positive.** In `OnboardingUITests`, give the Before-you-start audit a narrow issue filter: ignore an issue only when `auditType == .contrast` **and** the element label is exactly "Turn on the two required items to continue." Add a comment: "False positive on iPhone 18 Pro Max (iOS 27.0): measured #4A5750 on #FAFCF9 = 7.35:1; passes on iPhone 17/17e/Air/18 Pro."
- [ ] **Step 4: README.** Fix the line that says editing consent copy fails the test so it describes the new single-source mechanism. Fix the line that calls the logotype a fixed size; it now scales with `@ScaledMetric`.
- [ ] **Step 5: CI.** In `ios.yml`, select the newest **non-beta** Xcode: `ls -d /Applications/Xcode_*.app | grep -v -i beta | sort -V | tail -1`.
- [ ] **Step 6: Lint.**
  - The burn rule becomes `\bburn(s|ed|ing|t)?\s+\d[\d,.]*\s*(k?cals?|calories)\b`.
  - The before/after rule becomes `\bbefore[\s-]*(and|/|&)[\s-]*after\b`.
  - The completeness check skips entries with `"shouldTranslate": false`.
  - It treats an entry as translated when it has a direct `stringUnit` or a `variations` tree whose leaf `stringUnit`s are all translated.
  - Add tests for "Burn 1,200 calories", "Burnt 200 kcal", "burn 200 cals", "Before-and-after", a `shouldTranslate:false` entry (not flagged), and a nested variations entry (not flagged when its leaves are translated).
- [ ] **Step 7: Hit areas.** On the plain buttons in `NoticeCard` (action) and `AdCard` ("Why this ad"), put the frame and `.contentShape(Rectangle())` **inside** the button label, so the 44 pt area is tappable. Run the design-system tests.
- [ ] **Step 8:** Run every test command (all green) and both lints, then commit `fix(app): consent copy single source, audit filter, CI and lint gates`.

---

### Task 2: Move domain enums into NuriDomain; add units

**Files:**
- Create: `ios/Packages/NuriEngines/Sources/NuriDomain/FoodGroup.swift`, `FoodSource.swift`, `Units.swift`
- Test: `ios/Packages/NuriEngines/Tests/NuriDomainTests/UnitsTests.swift`, `FoodGroupDomainTests.swift`
- Modify: `ios/Packages/NuriDesignSystem/Package.swift`, rename `Sources/DesignSystem/FoodGroup.swift` → `FoodGroup+Colors.swift`, `Components/SourceLabel.swift`, DS tests as needed, and app files that use `FoodGroup` (add `import NuriDomain`).

**Interfaces:**
- Produces (NuriDomain):
  - `public enum FoodGroup: String, CaseIterable, Codable, Sendable` with cases `vegetables fruit grains protein legumesAndNuts dairyAndAlternatives` (same raw values as today).
  - `public enum FoodSource: String, CaseIterable, Codable, Sendable` with cases `verified manufacturer community userCreated photoEstimate`.
  - `public enum UnitSystem: String, CaseIterable, Codable, Sendable` with `metric` and `imperial`, plus `static func defaultFor(regionCode: String?) -> UnitSystem` (US, LR and MM give imperial).
  - `public enum BodyUnits` with `cm(feet:inches:)`, `feetAndInches(cm:) -> (feet: Int, inches: Int)`, `kg(pounds:)` and `pounds(kg:)`.
- Produces (DesignSystem):
  - `extension FoodGroup { var fill: RGB; var ring: ThemedColor }`, unchanged values.
  - `extension FoodSource { var symbolName: String; var color: ThemedColor }`.
  - `public typealias SourceKind = FoodSource`.
  - `SourceLabel` takes a `FoodSource`.

- [ ] **Step 1: Failing tests** (`UnitsTests`):
```swift
import Testing
@testable import NuriDomain

@Suite struct UnitsTests {
    @Test func regionDefaults() {
        #expect(UnitSystem.defaultFor(regionCode: "US") == .imperial)
        #expect(UnitSystem.defaultFor(regionCode: "kr") == .metric)
        #expect(UnitSystem.defaultFor(regionCode: nil) == .metric)
    }
    @Test func heightRoundTrip() {
        #expect(abs(BodyUnits.cm(feet: 5, inches: 10) - 177.8) < 0.001)
        #expect(BodyUnits.feetAndInches(cm: 177.8) == (5, 10))
        #expect(BodyUnits.feetAndInches(cm: 182.88) == (6, 0))   // 72 in, no "5 ft 12 in"
    }
    @Test func weightRoundTrip() {
        #expect(abs(BodyUnits.kg(pounds: 150) - 68.0388555) < 0.0001)
        #expect(abs(BodyUnits.pounds(kg: 68.0388555) - 150) < 0.0001)
    }
}
```
`FoodGroupDomainTests`: six cases, and the raw values are exactly `vegetables`, `fruit`, `grains`, `protein`, `legumesAndNuts`, `dairyAndAlternatives` (persisted values must never change).
- [ ] **Step 2: RED.**
- [ ] **Step 3: Implement.**

`Units.swift`:
```swift
/// How the person prefers to see height and weight. Engines always work in centimeters and kilograms.
public enum UnitSystem: String, CaseIterable, Codable, Sendable {
    case metric, imperial

    public static func defaultFor(regionCode: String?) -> UnitSystem {
        guard let code = regionCode?.uppercased() else { return .metric }
        return ["US", "LR", "MM"].contains(code) ? .imperial : .metric
    }
}

public enum BodyUnits {
    public static let centimetersPerInch = 2.54
    public static let kilogramsPerPound = 0.45359237

    public static func cm(feet: Int, inches: Int) -> Double { Double(feet * 12 + inches) * centimetersPerInch }

    public static func feetAndInches(cm: Double) -> (feet: Int, inches: Int) {
        let totalInches = Int((cm / centimetersPerInch).rounded())
        return (totalInches / 12, totalInches % 12)
    }

    public static func kg(pounds: Double) -> Double { pounds * kilogramsPerPound }
    public static func pounds(kg: Double) -> Double { kg / kilogramsPerPound }
}
```
Move the enum declarations for `FoodGroup` and `FoodSource` into NuriDomain unchanged, and keep their colors and icons in DesignSystem as extensions. In `NuriDesignSystem/Package.swift`, add `dependencies: [.package(path: "../NuriEngines")]` and give the `DesignSystem` target `.product(name: "NuriDomain", package: "NuriEngines")`. Use `@_exported import NuriDomain` in one DesignSystem file so existing `import DesignSystem` callers keep compiling. Still add `import NuriDomain` explicitly in app files that name `FoodGroup`.
- [ ] **Step 4: GREEN.** Run all three package suites (engines, design system) and the app test command. Every existing test must pass unchanged in behavior.
- [ ] **Step 5: Commit**: `refactor(domain): food groups, sources and units live in NuriDomain`

---

### Task 3: Persistence package: versioned SwiftData schema and models

**Files:**
- Create: `ios/Packages/NuriPersistence/Package.swift`, `Sources/Persistence/Schema.swift`, `Sources/Persistence/Models.swift`
- Test: `Tests/PersistenceTests/SchemaTests.swift`

**Interfaces:**
- Produces:
  - `@Model` classes `ProfileRecord`, `FoodRecord`, `MealEntryRecord`, `ActivityLogRecord` and `ConsentEventRecord` (fields below).
  - `enum NuriSchemaV1: VersionedSchema` and `enum NuriMigrationPlan: SchemaMigrationPlan`.
  - `enum NuriStore`, with `@MainActor static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer`.

- [ ] **Step 1: Package.swift**
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NuriPersistence",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Persistence", targets: ["Persistence"])],
    dependencies: [.package(path: "../NuriEngines")],
    targets: [
        .target(name: "Persistence", dependencies: [
            .product(name: "NuriDomain", package: "NuriEngines"),
            .product(name: "NutritionEngine", package: "NuriEngines"),
            .product(name: "ActivityEngine", package: "NuriEngines"),
        ]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"]),
    ]
)
```
- [ ] **Step 2: Failing test** `SchemaTests.swift`:
```swift
import Foundation
import SwiftData
import Testing
@testable import Persistence

@MainActor
@Suite struct SchemaTests {
    @Test func inMemoryContainerStoresEveryModel() throws {
        let container = try NuriStore.makeContainer(inMemory: true)
        let context = container.mainContext
        context.insert(ProfileRecord(birthYear: 1990, sexForEquation: nil, heightCm: 170, weightKg: 65,
                                     activityLevel: "lightlyActive", goal: "maintain", unitSystem: "metric", bmiStandard: "asianPacific"))
        context.insert(FoodRecord(name: "Rice, white, cooked", foodGroup: "grains", servingLabel: "1 bowl", gramsPerServing: 210,
                                  energyKcalPer100g: 130, source: "userCreated"))
        context.insert(MealEntryRecord(foodID: nil, foodName: "Rice, white, cooked", foodGroup: "grains", mealType: "lunch",
                                       consumedAt: Date(timeIntervalSince1970: 1_800_000_000), dayKey: "2027-01-15",
                                       quantity: 1, unitLabel: "1 bowl", grams: 210, energyKcal: 273, source: "userCreated"))
        context.insert(ActivityLogRecord(activityTypeID: "walking", startAt: Date(timeIntervalSince1970: 1_800_000_000), dayKey: "2027-01-15",
                                         durationMinutes: 30, intensity: "moderate", met: 3.5, energyKcal: nil,
                                         energySource: "manualMET", catalogVersion: "nuri-met-2026.1"))
        context.insert(ConsentEventRecord(kind: "granted", adultConfirmed: true, healthDataConsented: true, analyticsOptIn: false,
                                          consentVersion: "2026-10-10", localeIdentifier: "en_US", recordedAt: .now))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<ProfileRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<FoodRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<MealEntryRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ActivityLogRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ConsentEventRecord>()) == 1)
    }

    @Test func schemaIsVersioned() {
        #expect(NuriSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(NuriSchemaV1.models.count == 5)
    }
}
```
- [ ] **Step 3: RED.**
- [ ] **Step 4: Implement**

`Models.swift`:
```swift
import Foundation
import SwiftData

/// One profile per device. Year of birth only (data minimization); sex is optional and only feeds the energy formula.
@Model
public final class ProfileRecord {
    public var birthYear: Int
    public var sexForEquation: String?
    public var heightCm: Double
    public var weightKg: Double
    public var activityLevel: String
    public var goal: String
    public var unitSystem: String
    public var bmiStandard: String
    public var lossDeficitKcal: Double
    public var activityShare: Double
    public var manualTargetKcal: Double?
    public var tracksWithoutGuide: Bool
    public var readinessYes: [String]
    public var preferredActivityIDs: [String]
    public var equipment: [String]
    public var mobility: [String]
    public var updatedAt: Date

    public init(birthYear: Int, sexForEquation: String?, heightCm: Double, weightKg: Double, activityLevel: String, goal: String,
                unitSystem: String, bmiStandard: String, lossDeficitKcal: Double = 250, activityShare: Double = 0.5,
                manualTargetKcal: Double? = nil, tracksWithoutGuide: Bool = false, readinessYes: [String] = [],
                preferredActivityIDs: [String] = [], equipment: [String] = [], mobility: [String] = [], updatedAt: Date = .now) {
        self.birthYear = birthYear
        self.sexForEquation = sexForEquation
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityLevel = activityLevel
        self.goal = goal
        self.unitSystem = unitSystem
        self.bmiStandard = bmiStandard
        self.lossDeficitKcal = lossDeficitKcal
        self.activityShare = activityShare
        self.manualTargetKcal = manualTargetKcal
        self.tracksWithoutGuide = tracksWithoutGuide
        self.readinessYes = readinessYes
        self.preferredActivityIDs = preferredActivityIDs
        self.equipment = equipment
        self.mobility = mobility
        self.updatedAt = updatedAt
    }
}

/// A food the person created (label values). Database foods arrive with the food-data pipeline.
@Model
public final class FoodRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var foodGroup: String
    public var servingLabel: String
    public var gramsPerServing: Double
    public var energyKcalPer100g: Double
    public var proteinGPer100g: Double?
    public var carbsGPer100g: Double?
    public var fatGPer100g: Double?
    public var fiberGPer100g: Double?
    public var source: String
    public var isFavorite: Bool
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, foodGroup: String, servingLabel: String, gramsPerServing: Double,
                energyKcalPer100g: Double, proteinGPer100g: Double? = nil, carbsGPer100g: Double? = nil, fatGPer100g: Double? = nil,
                fiberGPer100g: Double? = nil, source: String, isFavorite: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.foodGroup = foodGroup
        self.servingLabel = servingLabel
        self.gramsPerServing = gramsPerServing
        self.energyKcalPer100g = energyKcalPer100g
        self.proteinGPer100g = proteinGPer100g
        self.carbsGPer100g = carbsGPer100g
        self.fatGPer100g = fatGPer100g
        self.fiberGPer100g = fiberGPer100g
        self.source = source
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }
}

/// A diary entry. Nutrition is a snapshot so history never changes when a food is edited (spec §6.2).
@Model
public final class MealEntryRecord {
    @Attribute(.unique) public var id: UUID
    public var foodID: UUID?
    public var foodName: String
    public var foodGroup: String
    public var mealType: String
    public var consumedAt: Date
    public var dayKey: String
    public var quantity: Double
    public var unitLabel: String
    public var grams: Double
    public var energyKcal: Double
    public var proteinG: Double?
    public var carbsG: Double?
    public var fatG: Double?
    public var fiberG: Double?
    public var source: String
    public var createdAt: Date
    public var deletedAt: Date?

    public init(id: UUID = UUID(), foodID: UUID?, foodName: String, foodGroup: String, mealType: String, consumedAt: Date, dayKey: String,
                quantity: Double, unitLabel: String, grams: Double, energyKcal: Double, proteinG: Double? = nil, carbsG: Double? = nil,
                fatG: Double? = nil, fiberG: Double? = nil, source: String, createdAt: Date = .now, deletedAt: Date? = nil) {
        self.id = id
        self.foodID = foodID
        self.foodName = foodName
        self.foodGroup = foodGroup
        self.mealType = mealType
        self.consumedAt = consumedAt
        self.dayKey = dayKey
        self.quantity = quantity
        self.unitLabel = unitLabel
        self.grams = grams
        self.energyKcal = energyKcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.source = source
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }
}

@Model
public final class ActivityLogRecord {
    @Attribute(.unique) public var id: UUID
    public var activityTypeID: String
    public var startAt: Date
    public var dayKey: String
    public var durationMinutes: Double
    public var intensity: String
    public var met: Double
    public var energyKcal: Double?
    public var energySource: String
    public var catalogVersion: String
    public var createdAt: Date
    public var deletedAt: Date?

    public init(id: UUID = UUID(), activityTypeID: String, startAt: Date, dayKey: String, durationMinutes: Double, intensity: String,
                met: Double, energyKcal: Double?, energySource: String, catalogVersion: String, createdAt: Date = .now, deletedAt: Date? = nil) {
        self.id = id
        self.activityTypeID = activityTypeID
        self.startAt = startAt
        self.dayKey = dayKey
        self.durationMinutes = durationMinutes
        self.intensity = intensity
        self.met = met
        self.energyKcal = energyKcal
        self.energySource = energySource
        self.catalogVersion = catalogVersion
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }
}

/// Append-only consent history (PIPA proof of consent): never edited, only added to, and deleted only with everything else.
@Model
public final class ConsentEventRecord {
    public var kind: String
    public var adultConfirmed: Bool
    public var healthDataConsented: Bool
    public var analyticsOptIn: Bool
    public var consentVersion: String
    public var localeIdentifier: String
    public var recordedAt: Date

    public init(kind: String, adultConfirmed: Bool, healthDataConsented: Bool, analyticsOptIn: Bool, consentVersion: String,
                localeIdentifier: String, recordedAt: Date) {
        self.kind = kind
        self.adultConfirmed = adultConfirmed
        self.healthDataConsented = healthDataConsented
        self.analyticsOptIn = analyticsOptIn
        self.consentVersion = consentVersion
        self.localeIdentifier = localeIdentifier
        self.recordedAt = recordedAt
    }
}
```

`Schema.swift`:
```swift
import Foundation
import SwiftData

public enum NuriSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [ProfileRecord.self, FoodRecord.self, MealEntryRecord.self, ActivityLogRecord.self, ConsentEventRecord.self]
    }
}

public enum NuriMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [NuriSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public enum NuriStore {
    /// The app's store. On iOS, `url` should point inside Application Support with file protection enabled by the caller.
    @MainActor
    public static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: NuriSchemaV1.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let url {
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
        return try ModelContainer(for: schema, migrationPlan: NuriMigrationPlan.self, configurations: [configuration])
    }
}
```
If Swift 6 strict concurrency rejects anything in the schema statics or `@Model` macro output, make the smallest fix and record it.
- [ ] **Step 5: GREEN**, with no warnings: `swift test --package-path ios/Packages/NuriPersistence`.
- [ ] **Step 6: Commit**: `feat(persistence): versioned SwiftData schema and models`

---

### Task 4: Repositories: profile, consent log, data wiper

**Files:**
- Create: `Sources/Persistence/ProfileRepository.swift`, `ConsentLog.swift`, `DataWiper.swift`
- Test: `Tests/PersistenceTests/ProfileRepositoryTests.swift`, `ConsentLogTests.swift`, `DataWiperTests.swift`

**Interfaces:**
- Produces:
  - `public struct ProfileDraft: Equatable, Sendable`, with the same fields as `ProfileRecord` minus `updatedAt`, typed with domain enums.
  - `@MainActor public final class ProfileRepository(context:)`, with `current() throws -> ProfileRecord?`, `draft() throws -> ProfileDraft?`, `save(_ draft: ProfileDraft, now: Date) throws` (upserts the single record) and `exists() throws -> Bool`.
  - `public struct ConsentEvent: Equatable, Sendable`, with `kind` (`.granted`/`.withdrawn`), `adultConfirmed`, `healthDataConsented`, `analyticsOptIn`, `consentVersion`, `localeIdentifier` and `recordedAt`.
  - `@MainActor public protocol ConsentLogging { func append(_ event: ConsentEvent) throws; func events() throws -> [ConsentEvent] }`.
  - `@MainActor public final class SwiftDataConsentLog: ConsentLogging`.
  - `@MainActor public enum DataWiper { static func deleteEverything(in context: ModelContext) throws }`.

`ProfileDraft`:
```swift
import NuriDomain
import NutritionEngine
import ActivityEngine

public struct ProfileDraft: Equatable, Sendable {
    public var birthYear: Int
    public var sex: SexForEquation?
    public var heightCm: Double
    public var weightKg: Double
    public var activityLevel: ActivityLevel
    public var goal: Goal
    public var unitSystem: UnitSystem
    public var bmiStandard: BMIStandard
    public var lossDeficitKcal: Double
    public var activityShare: Double
    public var manualTargetKcal: Double?
    public var tracksWithoutGuide: Bool
    public var readinessYes: Set<ReadinessQuestion>
    public var preferredActivityIDs: [String]
    public var equipment: Set<String>
    public var mobility: Set<MobilityPreference>
    // memberwise public init with defaults: lossDeficitKcal 250, activityShare 0.5, manualTargetKcal nil, tracksWithoutGuide false,
    // readinessYes [], preferredActivityIDs [], equipment [], mobility []
}
```
`ProfileRepository.save` maps the enums to raw strings. Sets are stored sorted, so the output is deterministic. `draft()` maps back, and unknown raw values fall back to safe defaults (`.sedentary`, `.maintain`, `.metric`, `.who`, dropping unknown readiness/mobility entries).

`DataWiper.deleteEverything`: `try context.delete(model: X.self)` for all five models, then `try context.save()`.

- [ ] **Step 1: Failing tests:**
  - Save then draft round-trips every field, including readiness, mobility and equipment sets.
  - A second save updates the single record (count stays 1) and bumps `updatedAt`.
  - `exists()` is false on an empty store and true after a save.
  - A raw `activityLevel` of "flying" decodes to `.sedentary`.
  - The consent log appends granted then withdrawn and returns both in `recordedAt` order. Records are never mutated: write a test that appends 2 and asserts the first is unchanged.
  - `deleteEverything` leaves all five fetch counts at 0.
- [ ] **Step 2: RED.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: GREEN.**
- [ ] **Step 5: Commit**: `feat(persistence): profile repository, consent log, delete everything`

---

### Task 5: Profile → engine mapping and the daily guide

**Files:**
- Create: `Sources/Persistence/ProfileMapping.swift`
- Test: `Tests/PersistenceTests/ProfileMappingTests.swift`

**Interfaces:**
- Produces:
  - `extension ProfileDraft`:
    - `ageYears(in year: Int) -> Int`
    - `bodyProfile(inYear:) -> BodyProfile`
    - `readiness: ReadinessScreen`
  - `public enum DailyGuide: Equatable, Sendable`:
    - `calculated(EnergyTargetEstimate)`
    - `manual(kcal: Double, assessment: ManualTargetAssessment)`
    - `needsManualTarget`, when no sex is given and there is no manual number
    - `none`, when tracking without a guide
  - `extension ProfileDraft`:
    - `dailyGuide(inYear:) throws(ProfileValidationError) -> DailyGuide`
    - `kcal` (computed on `DailyGuide`) returns `Double?`

Rules:
- If `tracksWithoutGuide`, the result is `.none`.
- Otherwise, if there is a `manualTargetKcal`, the result is `.manual(kcal, EnergyTargetCalculator.assessManualTarget(kcal, sex:))`.
- Otherwise, for `goal == .gradualLoss`, the adjustment is `GoalAdjustmentPolicy.foodAdjustment(lossDeficitKcal:activityShare:)`. For other goals it is nil, so the engine default applies.
- `estimate(profile:adjustmentKcal:)` returns `.calculated(...)`, or `.needsManualTarget` when it returns nil because no sex was given.

- [ ] **Step 1: Failing tests:**
  - Age is `year − birthYear`.
  - `bodyProfile` maps all fields.
  - A male, 1996, 180 cm, 80 kg, moderately active, maintain profile in 2026 gives `.calculated` with `targetKcal == 2760` (the same vector as the engines).
  - The same profile with gradual loss, deficit 250 and share 0.5 gives an adjustment of −125 and a target of `roundTo(2759 - 125, 10) = 2630`.
  - No sex gives `.needsManualTarget`. No sex with manual 1800 gives `.manual(1800, .ok)`.
  - Female with manual 1100 gives `.manual(1100, .belowRecommendedMinimum(minimumKcal: 1200))`.
  - `tracksWithoutGuide` gives `.none`.
  - Age under 18 throws `.ageOutOfRange`.
- [ ] **Step 2: RED.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: GREEN.**
- [ ] **Step 5: Commit**: `feat(persistence): profile mapping and daily guide`

---

### Task 6: Export: CSV/JSON builders and file writer

**Files:**
- Create: `Sources/Persistence/DataExport.swift`
- Test: `Tests/PersistenceTests/DataExportTests.swift`

**Interfaces:**
- Produces:
  - `public struct ExportFile: Equatable, Sendable { name: String; data: Data }`
  - `@MainActor public enum DataExport`, with:
    - `static let schemaVersion = 1`
    - `static func files(from context: ModelContext, exportedAt: Date) throws -> [ExportFile]`
    - `static func write(_ files: [ExportFile], to directory: URL) throws -> [URL]`
    - `static func csv(_ rows: [[String]]) -> String`

Files and columns:
- **`profile.json`:** the profile draft fields as raw values.
- **`foods.csv`:** id, name, food_group, serving_label, grams_per_serving, energy_kcal_per_100g, protein_g_per_100g, carbs_g_per_100g, fat_g_per_100g, fiber_g_per_100g, source, is_favorite, created_at.
- **`meal_entries.csv`:** id, consumed_at, day_key, meal_type, food_name, food_group, quantity, unit_label, grams, energy_kcal, protein_g, carbs_g, fat_g, fiber_g, source, deleted_at.
- **`activities.csv`:** id, start_at, day_key, activity_type_id, duration_minutes, intensity, met, energy_kcal, energy_source, catalog_version, deleted_at.
- **`consent_events.json`:** the full consent history.
- **`full_backup.json`:** `{ "schemaVersion": 1, "exportedAt": ISO8601, "profile": {...}|null, "foods": [...], "mealEntries": [...], "activities": [...], "consentEvents": [...] }`.

Format rules:
- Dates are ISO 8601 UTC.
- Numbers use a "." decimal separator and no grouping (locale-independent).
- Missing optionals are empty cells in CSV and `null` in JSON.
- CSV follows RFC 4180: quote fields containing a comma, quote, CR or LF, and double any embedded quotes.
- Line endings are `\r\n`, with a header row.
- Soft-deleted rows are included and carry their `deleted_at`, since the export is the complete record.

- [ ] **Step 1: Failing tests:**
  - CSV quoting: `a,b` → `"a,b"`, `say "hi"` → `"say ""hi"""`, a newline is quoted, and a plain value is not.
  - An empty store gives 6 files with a header-only CSV, a `null` profile, and `full_backup.json` with schemaVersion 1.
  - A populated store gives meal CSV row values equal to the inserted snapshot, Korean food names round-trip in UTF-8, and `full_backup.json` decodes with matching counts.
  - `write` creates the files with the exact names in the directory and returns their URLs.
  - Numbers stay locale-independent: 1234.5 is written as `1234.5`.
- [ ] **Step 2: RED.**
- [ ] **Step 3: Implement** with Codable DTO structs and `JSONEncoder` (`.iso8601`, `.sortedKeys`, `.prettyPrinted`).
- [ ] **Step 4: GREEN.**
- [ ] **Step 5: Commit**: `feat(persistence): data export as CSV and JSON`

---

### Task 7: Wire persistence into the app; AppState profile stage and consent log

**Files:**
- Modify: `ios/Nuri.xcodeproj/project.pbxproj` (add the package and product), `ios/App/NuriApp.swift`, `ios/App/AppState.swift`, `ios/App/RootView.swift`, `ios/NuriTests/AppStateTests.swift`

**Interfaces:**
- `OnboardingStage` gains `.profile`.
- `AppState.init(defaults:consentLog:profileExists:)`, where `consentLog: (any ConsentLogging)? = nil` and `profileExists: @MainActor () -> Bool = { false }`.
- `recordConsent` now sets `.profile` and appends a `.granted` event; `completeProfile()` moves `.profile` to `.complete`.
- `withdrawConsent(now:)` appends a `.withdrawn` event and returns, leaving the caller to wipe data and then call `startOver()`.
- Stage resolution:
  - A stored `.complete` needs a current-version consent **and** `profileExists()`. A missing profile gives `.profile`.
  - A stored `.profile` with no current consent gives `.consent`, or `.welcome` when there is no record at all.

- [ ] **Step 1: pbxproj.** Add these, following the existing NuriDesignSystem entries exactly:
  - `XCLocalSwiftPackageReference` `A10000000000000000000503` with `relativePath = Packages/NuriPersistence`, added to `packageReferences`.
  - `XCSwiftPackageProductDependency` `A10000000000000000000205` with `productName = Persistence`, added to the Nuri target's `packageProductDependencies`.
  - `PBXBuildFile` `A10000000000000000000105`, "Persistence in Frameworks", added to the Nuri Frameworks phase.

  Build to confirm.
- [ ] **Step 2: Failing tests** (update `AppStateTests`; previous expectations of `.complete` after consent become `.profile`):
  - Consent gives `.profile` and the log has 1 granted event (use an in-memory fake `ConsentLogging` defined in the test).
  - `completeProfile` gives `.complete`.
  - Relaunch with a stored `.complete`, current consent and `profileExists` true gives `.complete`.
  - The same with `profileExists` false gives `.profile`.
  - `completeProfile` while still at `.consent` does nothing.
  - `withdrawConsent` appends a withdrawn event carrying the previous consent's items.
  - The fake log records the `Locale.current.identifier` locale.
- [ ] **Step 3: Implement.** `ConsentEvent.localeIdentifier = Locale.current.identifier`.

  `NuriApp` becomes the composition root:
  - Create the store at `Application Support/Nuri/Nuri.store`.
  - On iOS, create the folder with `FileManager.default.createDirectory(... attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])`.
  - In DEBUG with `-uiTestFreshState`, use an **in-memory** container instead of the file store, alongside the existing defaults reset.
  - Pass `SwiftDataConsentLog(context: container.mainContext)` and `profileExists: { (try? ProfileRepository(context: container.mainContext).exists()) ?? false }` to `AppState`.
  - Add `.modelContainer(container)` to the scene.

  `RootView`: `.profile` shows `ProfileFlow` from Task 8. For this task use a temporary `Text(verbatim: "Profile")` placeholder view named `ProfileFlow`.
- [ ] **Step 4: GREEN.** Run the app unit tests and persistence tests. UI tests will fail at the profile step until Task 8; update them in Task 8, and say so in the report.
- [ ] **Step 5: Commit**: `feat(app): local store, consent history and a profile stage`

---

### Task 8: Profile onboarding UI

**Files:**
- Create: `ios/App/Onboarding/Profile/ProfileFlow.swift`, `ProfileSteps.swift`, `DailyGuideStep.swift`, `ProfileDraft+Defaults.swift`
- Modify: `ios/App/Localizable.xcstrings` (new keys below), `ios/App/RootView.swift`, `ios/NuriUITests/OnboardingUITests.swift`

**Behavior:**
- `ProfileFlow` is a `NavigationStack` with one step on screen at a time. It shows a "Step %lld of %lld" caption (`Text("Step \(index) of \(total)")`, key `Step %lld of %lld`), the step content in an inset-grouped `List` styled with `.nuriGroupedList()`, and a bottom `safeAreaInset` holding a primary "Continue" button and, from step 2 on, a text "Back" button.
- The draft lives in `@State var draft: ProfileDraft`, initialized by `ProfileDraft.starting(regionCode:currentYear:)`:

  | Field | Default |
  |---|---|
  | birthYear | currentYear − 30 |
  | sex | nil |
  | height / weight | 170 cm / 65 kg |
  | activityLevel | `.lightlyActive` |
  | goal | `.maintain` |
  | unitSystem | from region |
  | bmiStandard | `BMIStandard.defaultStandard(forRegion:)` |
  | everything else | default |

Steps:
1. **About you.**
   - "Year of birth" is a `Picker` with the `.wheel` style, from currentYear − 100 to currentYear − 18.
   - "Sex for energy estimates" is a segmented `Picker` with Female, Male and Prefer not to say (nil). Footer: "Only used in the Mifflin-St Jeor formula. Choose Prefer not to say to set your daily guide yourself."
2. **Body.**
   - Units: segmented Metric / Imperial, which persists.
   - Height: metric is a `Stepper` from 100 to 250 cm, step 1, showing "%@ cm". Imperial is two wheel pickers, ft 3–8 and in 0–11.
   - Weight: a `TextField` with a decimal pad, bound through a formatter, in kg or lb. Validate against 30–350 kg after converting.
   - Continue is disabled until the values are in range, with an inline footnote "Enter a weight between %@ and %@."
3. **Activity level.** A list of 5 rows with checkmark selection: title plus one-line description (keys below).
4. **Goal.** A list of 6 rows with checkmark selection (keys below).
5. **A few health questions.** Seven `Toggle` rows (keys below), all off by default. Footer: "If any of these apply, Nuri suggests a light plan and recommends checking with a clinician first."
6. **Numbers.** A `Toggle` for "Hide numbers" (writes `appState.setHideNumbers`), with the footer key from YouView ("Hides calories, nutrients, grams, minutes and ads everywhere in Nuri.") and the extra note "You can change this anytime in You."
7. **Your daily guide** (`DailyGuideStep`).
   - If Hide numbers is on: show "Your daily guide is set. Numbers stay hidden." with "Review it anytime in You." The Finish button is enabled. For `.needsManualTarget`, offer only "Track without a guide", which sets `tracksWithoutGuide = true` and keeps numbers hidden.
   - If Hide numbers is off, switch on `draft.dailyGuide(inYear:)`:
     - `.calculated(e)`: a headline "About %@ kcal a day" (rounded, `.formatted()`), the caption "A starting estimate. Real needs vary." and three rows:
       - "Maintenance estimate" → `e.tdeeKcal` rounded to 10.
       - "Goal adjustment" → signed adjustment, or "None".
       - "Method" → "Mifflin-St Jeor".

       If `e.raisedToMinimum`, add the note "Raised to the commonly suggested minimum." If `e.lossNotAppliedUnderweight`, add the note "A weight-loss adjustment isn't used at your current BMI. Consider talking with a clinician."
     - `.needsManualTarget`: the text "Without a sex value, Nuri can't use the formula. Enter your own daily guide or track without one."
     - Always: a "Use my own number" `TextField` (number pad) that sets `manualTargetKcal`, and a "Track without a guide" toggle.
     - For `.manual(_, .belowRecommendedMinimum(m))`: a `NoticeCard` titled "That's below the commonly suggested minimum" with the message "Many people need at least %@ kcal a day. Consider talking with a registered dietitian or a clinician." This never blocks Finish.
   - "Finish" saves through `ProfileRepository(context: modelContext).save(draft, now: .now)` and calls `appState.completeProfile()`.
- The flow is also reused from You → "Your profile" in Plan B, so keep it free of onboarding-only assumptions apart from the Finish action, which is passed in as a closure.

**New strings (EN key → KO):**

| EN | KO |
|---|---|
| Step %lld of %lld | %2$lld단계 중 %1$lld단계 |
| Back | 이전 |
| About you | 나에 대해 |
| Year of birth | 출생 연도 |
| Sex for energy estimates | 에너지 추정에 쓰는 성별 |
| Female | 여성 |
| Male | 남성 |
| Prefer not to say | 밝히지 않음 |
| Only used in the Mifflin-St Jeor formula. Choose Prefer not to say to set your daily guide yourself. | Mifflin-St Jeor 공식에만 사용해요. 밝히지 않음을 선택하면 하루 가이드를 직접 정할 수 있어요. |
| Body | 신체 정보 |
| Units | 단위 |
| Metric | 미터법 |
| Imperial | 야드파운드법 |
| Height | 키 |
| Weight | 몸무게 |
| %@ cm | %@cm |
| %@ kg | %@kg |
| %@ lb | %@lb |
| %lld ft | %lldft |
| %lld in | %lldin |
| Enter a weight between %@ and %@. | 몸무게를 %@에서 %@ 사이로 입력해 주세요. |
| Activity level | 활동 수준 |
| Mostly sitting | 대부분 앉아서 지내요 |
| Little exercise, mostly desk work. | 운동은 거의 없고 주로 앉아서 일해요. |
| Lightly active | 가볍게 활동해요 |
| Light movement or exercise 1–3 days a week. | 일주일에 1–3일 가볍게 움직이거나 운동해요. |
| Moderately active | 적당히 활동해요 |
| Exercise 3–5 days a week. | 일주일에 3–5일 운동해요. |
| Very active | 활발하게 활동해요 |
| Hard exercise 6–7 days a week. | 일주일에 6–7일 강도 높게 운동해요. |
| Extra active | 매우 활발하게 활동해요 |
| Physical job or training twice a day. | 몸을 쓰는 일을 하거나 하루 두 번 훈련해요. |
| Goal | 목표 |
| Keep my weight steady | 지금 체중 유지하기 |
| Lose weight gradually | 천천히 체중 줄이기 |
| Gain weight gradually | 천천히 체중 늘리기 |
| Eat better | 더 균형 있게 먹기 |
| Support my training | 운동 뒷받침하기 |
| Just track, no goal | 목표 없이 기록만 하기 |
| A few health questions | 건강 관련 질문 몇 가지 |
| A doctor has said I have a heart condition | 의사에게 심장 질환이 있다는 말을 들었어요 |
| I feel chest pain during physical activity | 몸을 움직일 때 가슴 통증이 있어요 |
| I lose balance from dizziness or have fainted recently | 어지러워서 균형을 잃거나 최근 실신한 적이 있어요 |
| I have a bone or joint problem that activity could worsen | 활동하면 악화될 수 있는 뼈나 관절 문제가 있어요 |
| I take medicine for blood pressure or a heart condition | 혈압이나 심장 질환 약을 복용하고 있어요 |
| I am pregnant or gave birth in the last six months | 임신 중이거나 출산한 지 6개월이 지나지 않았어요 |
| I know of another reason I should not be active without advice | 조언 없이 활동하면 안 되는 다른 이유가 있어요 |
| If any of these apply, Nuri suggests a light plan and recommends checking with a clinician first. | 하나라도 해당하면 누리는 가벼운 플랜을 제안하고 먼저 의료 전문가와 상의하도록 권해요. |
| Numbers | 숫자 |
| You can change this anytime in You. | 언제든 나 탭에서 바꿀 수 있어요. |
| Your daily guide | 하루 가이드 |
| Your daily guide is set. Numbers stay hidden. | 하루 가이드가 정해졌어요. 숫자는 숨겨져요. |
| Review it anytime in You. | 언제든 나 탭에서 확인할 수 있어요. |
| About %@ kcal a day | 하루 약 %@kcal |
| A starting estimate. Real needs vary. | 시작을 위한 추정치예요. 실제 필요량은 사람마다 달라요. |
| Maintenance estimate | 유지 추정치 |
| Goal adjustment | 목표 조정 |
| None | 없음 |
| Method | 방법 |
| Mifflin-St Jeor | Mifflin-St Jeor |
| Raised to the commonly suggested minimum. | 일반적으로 권장되는 최소치로 올렸어요. |
| A weight-loss adjustment isn't used at your current BMI. Consider talking with a clinician. | 현재 BMI에서는 체중 감량 조정을 사용하지 않아요. 의료 전문가와 상의해 보세요. |
| Without a sex value, Nuri can't use the formula. Enter your own daily guide or track without one. | 성별 값이 없으면 공식을 사용할 수 없어요. 하루 가이드를 직접 입력하거나 가이드 없이 기록하세요. |
| Use my own number | 직접 입력하기 |
| Track without a guide | 가이드 없이 기록하기 |
| That's below the commonly suggested minimum | 일반적으로 권장되는 최소치보다 낮아요 |
| Many people need at least %@ kcal a day. Consider talking with a registered dietitian or a clinician. | 많은 사람에게 하루 최소 %@kcal가 필요해요. 영양사나 의료 전문가와 상의해 보세요. |
| Finish | 완료 |

Format keys: in Swift, `Text("Step \(i) of \(n)")` with `Int` gives `%lld`. Use `Text("\(value.formatted()) cm")` (String) for `%@`. The Korean "Step" value uses positional specifiers as shown.

- [ ] **Step 1: UI test (failing).**
  - Add a helper `completeProfile(app)` that taps Continue through the steps with default values; for weight, type "65" when the field is empty. On the Daily guide step, the default sex is nil, so turn on "Track without a guide" (identifier `profile.trackWithoutGuide`) and tap Finish (`profile.finish`).
  - Update the existing tests to call it after consent.
  - Add `testProfileWithSexShowsCalculatedGuide`: choose Male, keep the defaults, go to the guide step and assert a static text starting with "About " exists (identifier `profile.guideHeadline`).
  - Add a Korean smoke test (`-AppleLanguages (ko)`, `-AppleLocale ko_KR`) that completes onboarding using accessibility identifiers only, then asserts the My Nuri screen (`today.guide` or the Add food identifier) appears.
  - Add accessibility identifiers for every control the tests touch.
- [ ] **Step 2: RED.**
- [ ] **Step 3: Implement.** Add the strings and make sure the lint passes.
- [ ] **Step 4: GREEN.** Run all unit and UI tests, then capture screenshots of each step in light and dark plus step 7 in Korean to `build/screenshots/profile-*.png`.
- [ ] **Step 5: Commit**: `feat(app): profile onboarding with daily guide`

---

### Task 9: Privacy rights in You: full notice, export, delete everything, withdraw consent

**Files:**
- Modify: `ios/App/ConsentCopy.swift` (notice strings), `ios/App/Onboarding/DataUseView.swift`, `ios/App/Tabs/YouView.swift`, `ios/App/AppState.swift` (bump `consentVersion` to `"2026-10-10"` and the fingerprint), `ios/App/Localizable.xcstrings`, `ios/NuriTests/ConsentCopyTests.swift`, `ios/NuriUITests/OnboardingUITests.swift`
- Create: `ios/App/Tabs/DeleteDataView.swift`, `ios/App/Tabs/ExportView.swift`

**Behavior:**
- **The notice (`DataUseView`).** It uses only `ConsentCopy` notice constants, which join `ConsentCopy.all` so they are pinned. Items:
  - "Your profile": "Year of birth, sex for the energy formula (optional), height, weight, activity level and goal. Used for your daily guide and your plan."
  - "Health questions": "Your answers to the health questions. Used only to keep your plan safe."
  - "Foods and meals you add": existing detail.
  - "Activity you log or import": existing detail.
  - "Consent history": "When you agreed or withdrew, so we can show what you agreed to."
  - "How long we keep it": "On this device until you delete it. Delete everything anytime in You."
  - "Your choice": "You can refuse. Nuri can't work without storing food and activity data, so refusing means not using the app. Nothing else changes."
  - "Never": existing detail.
- **You → Privacy section:**
  - "Health data consent": Given on date — `Text(consent.recordedAt, format: .dateTime.year().month().day())`. Hidden numbers do not apply to dates.
  - "What we store and why".
  - "Export my data" opens `ExportView`. It builds files with `DataExport.files` and writes them with `DataExport.write` to a temporary folder. It shows the list of included files and the schema version ("Includes %lld files. Format version %lld."), with a `ShareLink(items: urls)` labelled "Share export" and "Exported on this device. Nothing is uploaded."
  - "Withdraw consent" (destructive) opens `DeleteDataView(mode: .withdraw)`.
  - "Delete all data" (destructive) opens `DeleteDataView(mode: .delete)`.
- **`DeleteDataView`:** explains the action.
  - Withdraw: "Nuri can't run without storing your food and activity data. Withdrawing deletes everything on this device and returns to the welcome screen."
  - Delete: "This deletes your profile, meals, activity, foods and consent history from this device. It can't be undone."
  - Typed confirmation (spec §5.8): a `TextField` that must equal the localized word "DELETE" / "삭제" (key `DELETE` → ko `삭제`) before the destructive button ("Delete everything") enables.
  - On confirm: for withdraw, call `appState.withdrawConsent()`. Then `DataWiper.deleteEverything(in: modelContext)`, `appState.startOver()`, and dismiss.
- **Remove the old "Start over" row.** "Delete all data" replaces it, and Start over's strings leave the catalog: remove the keys "Start over", "Start over?" and "This clears your choices on this device and returns to the welcome screen." so completeness and lint stay clean.
- **Bump `AppState.consentVersion`** to `"2026-10-10"`. The notice is part of the consent copy, so update `consentCopyFingerprint` as the test instructs.

**New strings (EN → KO):**

| EN | KO |
|---|---|
| Health questions | 건강 관련 질문 |
| Your answers to the health questions. Used only to keep your plan safe. | 건강 관련 질문에 대한 답이에요. 플랜을 안전하게 만드는 데에만 사용해요. |
| Year of birth, sex for the energy formula (optional), height, weight, activity level and goal. Used for your daily guide and your plan. | 출생 연도, 에너지 공식에 쓰는 성별(선택), 키, 몸무게, 활동 수준, 목표예요. 하루 가이드와 플랜에 사용해요. |
| Consent history | 동의 기록 |
| When you agreed or withdrew, so we can show what you agreed to. | 언제 동의하거나 철회했는지 기록해 무엇에 동의했는지 보여 드릴 수 있어요. |
| How long we keep it | 보관 기간 |
| On this device until you delete it. Delete everything anytime in You. | 직접 삭제할 때까지 이 기기에 보관해요. 언제든 나 탭에서 전부 삭제할 수 있어요. |
| Your choice | 선택할 권리 |
| You can refuse. Nuri can't work without storing food and activity data, so refusing means not using the app. Nothing else changes. | 동의하지 않을 수 있어요. 누리는 음식과 활동 데이터를 저장해야 작동하므로, 동의하지 않으면 앱을 사용할 수 없어요. 그 밖의 불이익은 없어요. |
| Export my data | 내 데이터 내보내기 |
| Includes %lld files. Format version %lld. | 파일 %1$lld개 포함, 형식 버전 %2$lld. |
| Share export | 내보낸 파일 공유 |
| Exported on this device. Nothing is uploaded. | 이 기기에서 내보냈어요. 아무것도 업로드되지 않아요. |
| Withdraw consent | 동의 철회 |
| Delete all data | 모든 데이터 삭제 |
| Nuri can't run without storing your food and activity data. Withdrawing deletes everything on this device and returns to the welcome screen. | 누리는 음식과 활동 데이터를 저장해야 작동해요. 동의를 철회하면 이 기기의 모든 데이터가 삭제되고 시작 화면으로 돌아가요. |
| This deletes your profile, meals, activity, foods and consent history from this device. It can't be undone. | 이 기기에서 프로필, 식사, 활동, 음식, 동의 기록을 삭제해요. 되돌릴 수 없어요. |
| Type %@ to confirm. | 확인하려면 %@를 입력하세요. |
| DELETE | 삭제 |
| Delete everything | 전부 삭제 |

- [ ] **Step 1: Failing tests.**
  - `ConsentCopyTests` with the new notice keys fails until the version and fingerprint are updated.
  - UI test `testDeleteAllDataReturnsToWelcome`: onboarding, then You, then Delete all data. Type "DELETE", tap "Delete everything", and assert the Welcome screen's "Use without an account" appears.
  - UI test `testExportShowsFileCount`: open You, then Export, and assert a static text with identifier `export.summary` exists.
  - Unit test (NuriTests, in-memory container, no UI): withdraw (an `AppState` with a fake log), then the wiper, then `startOver` leaves stage `.welcome`, the fake log has a withdrawn event, and the store counts are 0.
- [ ] **Step 2: RED.**
- [ ] **Step 3: Implement.** Use the lint and completeness checks to confirm the catalog stays clean after removing the Start over keys.
- [ ] **Step 4: GREEN.** Run all suites, then capture screenshots of You, Export and Delete in light and dark to `build/screenshots/privacy-*.png`.
- [ ] **Step 5: Commit**: `feat(app): full data notice, export, delete everything and withdraw consent`

---

### Task 10: README and docs

- [ ] Update `ios/README.md`: the persistence package, the store location and protection, what is stored, export format, and the delete/withdraw flows. Correct the "what's real vs not yet" list: profile onboarding and privacy rights are now real; Today, Diary, Plan and Add food come in Local Core B.
- [ ] Update `docs/superpowers/app-shell-followups.md`: mark the items resolved here as RESOLVED (local-core-a Task N).
- [ ] Run every test command once, paste the summary lines in the report, then commit `docs: local core A README and follow-ups`.

## Follow-up: Local Core B
- **Today with real data:** the world comes from today's food groups (resting groups from earlier in the week). The energy card uses `DailyLedger` with `baseTargetOnly`. The activity row shows logged minutes, labelled "not added to your guide". Everything numeric is gated.
- **Add food:** search your foods, create a food (label values plus a food group), food detail with portion and unit, meal and time, and a snapshot `MealEntryRecord`, with undo.
- **Diary:** day navigation, meals by type, swipe to delete with undo (soft delete), and day totals (gated).
- **Plan:** a `MovementPlanner` plan from the profile and the logged week (`WeekSummaryBuilder`, a pure function). Log it creates an `ActivityLogRecord`; plus swap and "Why this plan".
- **You:** profile edit (reuses `ProfileFlow`), units.
- **Hide numbers sweep UI test:** EN and KO, every screen.

# Nuri App Shell + Design System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A buildable, tested iOS app that ships Nuri's design system, the sign-in/first-run flow (guest path working; account sign-in shown as "arrives in a later build"), the four tabs with honest empty states, a working "Hide numbers" setting, Korean + English strings with a copy lint, and CI. Plus the parked engine fix (session cap for strength/balance).

**Architecture:**
- **`ios/Packages/NuriDesignSystem`:** a local Swift package, product `DesignSystem`. It holds palette tokens with WCAG contrast tests, typography, metrics, food-group colors, the world layout, and SwiftUI components.
- **`ios/Nuri.xcodeproj`:** the app, written by hand with Xcode 16+ synchronized folders (format proven on Xcode 27 in a spike). Targets `Nuri`, `NuriTests` (Swift Testing) and `NuriUITests` (XCTest UI). It links `NuriEngines` and `NuriDesignSystem` as local packages.
- **App state:** onboarding, consent and Hide numbers live in an `@Observable @MainActor AppState` backed by `UserDefaults`.

**Tech Stack:** Swift 6, SwiftUI (iOS 17+), Swift Testing, XCTest UI, String Catalogs, Python 3 (copy lint), GitHub Actions. No third-party dependencies.

**Spec:** `docs/specs/2026-10-05-nuri-design.md`, especially "Design direction (approved 2026-10-08)". Visual source: `docs/design/visual-direction/` (open the `.dc.html` boards as reference).

## Global Constraints
- iOS deployment target 17.0, `SWIFT_VERSION = 6.0`, iPhone only (`TARGETED_DEVICE_FAMILY = 1`), portrait. Packages: swift-tools-version 6.0, `.iOS(.v17), .macOS(.v14)`.
- No third-party dependencies. No `Any`/`AnyObject` in public API.
- Native iOS first: system `TabView`, `NavigationStack`, `List(.insetGrouped)`, sheets with Cancel, `Toggle`, SF Symbols, Dynamic Type text styles via `Font.system(_:design: .rounded, weight:)`. Never hard-coded point sizes except the 누리 logotype.
- Minimum touch target 44 pt; primary buttons 52 pt.
- Every color comes from `NuriPalette` (light + dark). Text pairs ≥ 4.5:1, non-text ≥ 3:1, enforced by tests.
- Food-group colors appear only in the world and its legend.
- Copy rules (spec §4 and the design direction):
  - Never moralize food. Never frame exercise as compensation.
  - Food words use "Add"; activity words use "Log".
  - The Hide numbers setting is never named after a condition.
  - Every user-facing string lives in `ios/App/Localizable.xcstrings` with English and Korean values. `scripts/lint_copy.py` must pass.
- When Hide numbers is on, no calories, grams, nutrients, minutes or ads are shown anywhere.
- No invented legal URLs, no fake sign-in. Account sign-in is shown as arriving in a later build.
- Test commands:
  - Engines: `swift test --package-path ios/Packages/NuriEngines`
  - Design system: `swift test --package-path ios/Packages/NuriDesignSystem`
  - App: `xcodebuild test -project ios/Nuri.xcodeproj -scheme Nuri -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/DerivedData`
  - Copy lint: `python3 scripts/lint_copy.py ios/App/Localizable.xcstrings`
- Commit after every task, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File Structure
```
ios/
  Packages/NuriEngines/…                       (exists; Task 1 edits MovementPlanner)
  Packages/NuriDesignSystem/
    Package.swift
    Sources/DesignSystem/Color/RGB.swift        RGB, ThemedColor, Contrast (WCAG)
    Sources/DesignSystem/Color/NuriPalette.swift semantic light/dark tokens
    Sources/DesignSystem/Color/Color+Nuri.swift SwiftUI Color bridging
    Sources/DesignSystem/FoodGroup.swift        six groups: fill, ring, globe
    Sources/DesignSystem/Typography.swift       Font.nuri* text styles
    Sources/DesignSystem/Metrics.swift          spacing, radii, sizes
    Sources/DesignSystem/World/WorldLayout.swift fixed slot per group (pure)
    Sources/DesignSystem/World/WorldView.swift  the signature world
    Sources/DesignSystem/Components/Buttons.swift, NuriCard.swift, ProgressBar.swift,
      SourceLabel.swift, NoticeCard.swift, Toast.swift, AdCard.swift
    Tests/DesignSystemTests/…
  Nuri.xcodeproj/project.pbxproj
  App/                                          (synchronized group → target Nuri)
    NuriApp.swift, RootView.swift, AppState.swift, AuthService.swift, EmailValidator.swift
    Onboarding/OnboardingFlow.swift, WelcomeView.swift, EmailSignInView.swift, ConsentView.swift, DataUseView.swift
    Tabs/MainTabView.swift, TodayView.swift, AddFoodSheet.swift, DiaryView.swift, PlanView.swift, YouView.swift
    Localizable.xcstrings, Assets.xcassets/
  NuriTests/AppStateTests.swift, EmailValidatorTests.swift
  NuriUITests/OnboardingUITests.swift
scripts/lint_copy.py, scripts/test_lint_copy.py
.github/workflows/ios.yml
```
Add `build/` to `.gitignore` (DerivedData location).

---

### Task 1: Engine fix: the session cap also limits strength and balance

**Files:**
- Modify: `ios/Packages/NuriEngines/Sources/ActivityEngine/MovementPlanner.swift` (strength and balance blocks inside `plan`)
- Test: `ios/Packages/NuriEngines/Tests/ActivityEngineTests/MovementPlannerTests.swift`
- Modify: `docs/superpowers/engines-followups.md` (mark the parked item resolved)

**Interfaces:**
- Consumes: existing `MovementPlanInput.maxSessionMinutes` (clamped to 10…90 inside `plan`), the daily `budget`, `fixedItem`, and `PlanNotice.cappedAtSessionMaximum`.
- Produces: no API change. Behavior: every plan item's `minutesHigh` ≤ the clamped `maxSessionMinutes`.

Rule:
- `strengthLimit = min(budget, Double(sessionCap))`. Add strength only when `strengthLimit >= 15`. Then `low = 15`, `high = Int(min(25, strengthLimit))`, and subtract `high` from the budget.
- Balance uses `balanceLimit = min(budget, Double(sessionCap))`, is added only when `>= 10`, with `low = 10` and `high = Int(min(15, balanceLimit))`.
- When strength or balance is due but the session cap (not the budget) shortens or drops it, append `.cappedAtSessionMaximum` once.
- When the budget drops it, the existing `.limitedByAvailableTime` behavior stays.

- [ ] **Step 1: Write failing tests** (append to `MovementPlannerTests`; reuse its `plan(_:)` helper and `catalog`):

```swift
    @Test func sessionCapShortensStrength() throws {
        let p = try plan { $0.maxSessionMinutes = 20 }
        let strength = try #require(p.items.first { $0.kind == .strength })
        #expect(strength.minutesLow == 15 && strength.minutesHigh == 20)
        #expect(p.notices.contains(.cappedAtSessionMaximum))
    }

    @Test func tinySessionCapDropsStrengthKeepsBalance() throws {
        let p = try plan { $0.profile.ageYears = 70; $0.maxSessionMinutes = 12 }
        #expect(!p.items.contains { $0.kind == .strength })
        let balance = try #require(p.items.first { $0.kind == .balance })
        #expect(balance.minutesLow == 10 && balance.minutesHigh == 12)
        #expect(p.items.allSatisfy { $0.minutesHigh <= 12 })
    }
```
Also, in the existing invariant sweep test, change the per-item session-cap assertion from aerobic-only to **every item** (`p.items.allSatisfy { $0.minutesHigh <= cap }`).

- [ ] **Step 2: Run, verify RED**: `swift test --package-path ios/Packages/NuriEngines --filter MovementPlannerTests` (`sessionCapShortensStrength` fails with high 25, and the sweep fails).
- [ ] **Step 3: Implement the rule** in the strength and balance blocks.
- [ ] **Step 4: Run the full engines suite, GREEN, no warnings.**
- [ ] **Step 5:** In `docs/superpowers/engines-followups.md`, change the parked "strength (15–25) and balance…" line's prefix to `- RESOLVED (app-shell Task 1):`.
- [ ] **Step 6: Commit**: `fix(activity): session cap limits strength and balance too`

---

### Task 2: Design system package: palette tokens with contrast tests

**Files:**
- Create: `ios/Packages/NuriDesignSystem/Package.swift`
- Create: `Sources/DesignSystem/Color/RGB.swift`, `Sources/DesignSystem/Color/NuriPalette.swift`
- Test: `Tests/DesignSystemTests/ContrastTests.swift`, `Tests/DesignSystemTests/PaletteTests.swift`

**Interfaces:**
- Produces: `RGB(hex: UInt32)` (`red`, `green`, `blue` in 0…1), `ThemedColor(light: UInt32, dark: UInt32)` with `.light`, `.dark`, `Contrast.relativeLuminance(_:)`, `Contrast.ratio(_:_:)`, and `NuriPalette` static `ThemedColor` tokens: `ground surface ink inkSoft tint tintPressed onTint progress track link separator fillSecondary sand verified manufacturer community adLabel adOutline notice noticeInk toast onToast toastAction disabledFill disabledText chevron`.

- [ ] **Step 1: Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NuriDesignSystem",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "DesignSystem", targets: ["DesignSystem"])],
    targets: [
        .target(name: "DesignSystem"),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
    ]
)
```

- [ ] **Step 2: Write failing tests**

`ContrastTests.swift`:
```swift
import Testing
@testable import DesignSystem

@Suite struct ContrastTests {
    @Test func whiteOnBlackIs21() {
        #expect(abs(Contrast.ratio(RGB(hex: 0xFFFFFF), RGB(hex: 0x000000)) - 21) < 0.01)
    }

    @Test func sameColorIs1() {
        #expect(Contrast.ratio(RGB(hex: 0x3B6A4A), RGB(hex: 0x3B6A4A)) == 1)
    }

    @Test func orderDoesNotMatter() {
        let a = RGB(hex: 0x4A5750), b = RGB(hex: 0xF2F4EF)
        #expect(Contrast.ratio(a, b) == Contrast.ratio(b, a))
    }

    @Test func knownPairMatchesReference() {
        // #4A5750 on #FFFFFF ≈ 7.58 (computed with the WCAG 2.x formula)
        #expect(abs(Contrast.ratio(RGB(hex: 0x4A5750), RGB(hex: 0xFFFFFF)) - 7.58) < 0.05)
    }

    @Test func hexChannels() {
        let c = RGB(hex: 0x336699)
        #expect(abs(c.red - 0.2) < 0.001 && abs(c.green - 0.4) < 0.001 && abs(c.blue - 0.6) < 0.001)
    }
}
```

`PaletteTests.swift`:
```swift
import Testing
@testable import DesignSystem

@Suite struct PaletteTests {
    typealias P = NuriPalette

    // (foreground, background, label) — text must reach 4.5:1 in light AND dark
    static let textPairs: [(ThemedColor, ThemedColor, String)] = [
        (P.ink, P.ground, "ink/ground"), (P.ink, P.surface, "ink/surface"),
        (P.inkSoft, P.ground, "inkSoft/ground"), (P.inkSoft, P.surface, "inkSoft/surface"),
        (P.ink, P.fillSecondary, "ink/fillSecondary"), (P.inkSoft, P.fillSecondary, "inkSoft/fillSecondary"),
        (P.onTint, P.tint, "onTint/tint"), (P.onTint, P.tintPressed, "onTint/tintPressed"),
        (P.tint, P.surface, "tint/surface"), (P.tint, P.ground, "tint/ground"),
        (P.link, P.surface, "link/surface"), (P.link, P.ground, "link/ground"), (P.link, P.notice, "link/notice"),
        (P.verified, P.surface, "verified/surface"), (P.manufacturer, P.surface, "manufacturer/surface"),
        (P.community, P.surface, "community/surface"), (P.adLabel, P.surface, "adLabel/surface"),
        (P.noticeInk, P.notice, "noticeInk/notice"), (P.onToast, P.toast, "onToast/toast"),
        (P.toastAction, P.toast, "toastAction/toast"), (P.disabledText, P.disabledFill, "disabledText/disabledFill"),
    ]

    // non-text UI parts must reach 3:1
    static let partPairs: [(ThemedColor, ThemedColor, String)] = [
        (P.progress, P.track, "progress/track"), (P.progress, P.surface, "progress/surface"),
        (P.adOutline, P.surface, "adOutline/surface"), (P.adOutline, P.ground, "adOutline/ground"),
        (P.chevron, P.surface, "chevron/surface"),
    ]

    @Test(arguments: textPairs.indices)
    func textContrast(index: Int) {
        let (fg, bg, label) = Self.textPairs[index]
        #expect(Contrast.ratio(fg.light, bg.light) >= 4.5, "\(label) light")
        #expect(Contrast.ratio(fg.dark, bg.dark) >= 4.5, "\(label) dark")
    }

    @Test(arguments: partPairs.indices)
    func partContrast(index: Int) {
        let (fg, bg, label) = Self.partPairs[index]
        #expect(Contrast.ratio(fg.light, bg.light) >= 3, "\(label) light")
        #expect(Contrast.ratio(fg.dark, bg.dark) >= 3, "\(label) dark")
    }

    @Test func approvedHexValues() {
        #expect(P.ground.light == RGB(hex: 0xF2F4EF) && P.ground.dark == RGB(hex: 0x121714))
        #expect(P.tint.light == RGB(hex: 0x3B6A4A) && P.tint.dark == RGB(hex: 0x7FB58A))
        #expect(P.progress.light == RGB(hex: 0x4A82AB) && P.progress.dark == RGB(hex: 0x7EB0D6))
    }
}
```

- [ ] **Step 3: Run, verify RED**: `swift test --package-path ios/Packages/NuriDesignSystem` (compile errors).

- [ ] **Step 4: Implement**

`RGB.swift`:
```swift
import Foundation

/// An sRGB color with channels in 0…1.
public struct RGB: Equatable, Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }
}

/// A color token with a light and a dark appearance.
public struct ThemedColor: Equatable, Hashable, Sendable {
    public let light: RGB
    public let dark: RGB

    public init(light: UInt32, dark: UInt32) {
        self.light = RGB(hex: light)
        self.dark = RGB(hex: dark)
    }
}

/// WCAG 2.x relative luminance and contrast ratio.
public enum Contrast {
    public static func relativeLuminance(_ c: RGB) -> Double {
        func linear(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(c.red) + 0.7152 * linear(c.green) + 0.0722 * linear(c.blue)
    }

    public static func ratio(_ a: RGB, _ b: RGB) -> Double {
        let la = relativeLuminance(a), lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
```

`NuriPalette.swift`:
```swift
/// Semantic color tokens from the approved visual direction (docs/design/visual-direction).
public enum NuriPalette {
    public static let ground = ThemedColor(light: 0xF2F4EF, dark: 0x121714)
    public static let surface = ThemedColor(light: 0xFFFFFF, dark: 0x1C231E)
    public static let ink = ThemedColor(light: 0x17211B, dark: 0xEEF2EC)
    public static let inkSoft = ThemedColor(light: 0x4A5750, dark: 0xA9B5AC)
    public static let tint = ThemedColor(light: 0x3B6A4A, dark: 0x7FB58A)
    public static let tintPressed = ThemedColor(light: 0x2E5539, dark: 0x6A9F76)
    public static let onTint = ThemedColor(light: 0xFFFFFF, dark: 0x121714)
    public static let progress = ThemedColor(light: 0x4A82AB, dark: 0x7EB0D6)
    public static let track = ThemedColor(light: 0xE1E6E0, dark: 0x2E3832)
    public static let link = ThemedColor(light: 0x2F6690, dark: 0x9CC3E2)
    public static let separator = ThemedColor(light: 0xE7EBE5, dark: 0x2A332D)
    public static let fillSecondary = ThemedColor(light: 0xE3E8E2, dark: 0x2A332D)
    public static let sand = ThemedColor(light: 0xEADFC8, dark: 0x3A3326)
    public static let verified = ThemedColor(light: 0x2D5E3D, dark: 0x7FB58A)
    public static let manufacturer = ThemedColor(light: 0x2F6690, dark: 0x9CC3E2)
    public static let community = ThemedColor(light: 0x7A4E0C, dark: 0xD9A55B)
    public static let adLabel = ThemedColor(light: 0x3A403C, dark: 0xC9D1CB)
    public static let adOutline = ThemedColor(light: 0x858B83, dark: 0x7D857F)
    public static let notice = ThemedColor(light: 0xF5EEDC, dark: 0x2E2919)
    public static let noticeInk = ThemedColor(light: 0x17211B, dark: 0xE8D9B5)
    public static let toast = ThemedColor(light: 0x17211B, dark: 0x2B342E)
    public static let onToast = ThemedColor(light: 0xFFFFFF, dark: 0xFFFFFF)
    public static let toastAction = ThemedColor(light: 0xA9D3B4, dark: 0xA9D3B4)
    public static let disabledFill = ThemedColor(light: 0xD3D9D2, dark: 0x2A332D)
    public static let disabledText = ThemedColor(light: 0x4A5750, dark: 0x98A39B)
    public static let chevron = ThemedColor(light: 0x7F8882, dark: 0x8C978F)
}
```

- [ ] **Step 5: Run, verify GREEN** (all parameterized pairs pass; if any pair fails, report the measured ratio as NEEDS_CONTEXT, and do not change hex values on your own).
- [ ] **Step 6: Commit**: `feat(design): palette tokens with WCAG contrast tests`

---

### Task 3: Food groups, typography, metrics, Color bridging

**Files:**
- Create: `Sources/DesignSystem/FoodGroup.swift`, `Typography.swift`, `Metrics.swift`, `Color/Color+Nuri.swift`
- Test: `Tests/DesignSystemTests/FoodGroupTests.swift`

**Interfaces:**
- Produces:
  - `FoodGroup` (CaseIterable: `vegetables fruit grains protein legumesAndNuts dairyAndAlternatives`) with `fill: RGB` and `ring: ThemedColor`.
  - `WorldPalette.globe: ThemedColor`.
  - `Font.nuriLargeTitle, nuriTitle, nuriTitle2, nuriHeadline, nuriBody, nuriBodyEmphasis, nuriSubheadline, nuriSubheadlineEmphasis, nuriFootnote, nuriFootnoteEmphasis, nuriCaption`.
  - `NuriMetrics` (`screenMargin 16`, `minTouch 44`, `buttonHeight 52`, `radiusControl 12`, `radiusButton 14`, `radiusCard 16`).
  - `Color(_ themed: ThemedColor)`, and `Color.nuriGround`, `.nuriSurface`, `.nuriInk`, `.nuriInkSoft`, `.nuriTint`, `.nuriTintPressed`, `.nuriOnTint`, `.nuriProgress`, `.nuriTrack`, `.nuriLink`, `.nuriSeparator`, `.nuriFillSecondary`, `.nuriSand`, `.nuriVerified`, `.nuriManufacturer`, `.nuriCommunity`, `.nuriAdLabel`, `.nuriAdOutline`, `.nuriNotice`, `.nuriNoticeInk`, `.nuriToast`, `.nuriOnToast`, `.nuriToastAction`, `.nuriDisabledFill`, `.nuriDisabledText`, `.nuriChevron`.

- [ ] **Step 1: Failing tests** (`FoodGroupTests.swift`):
```swift
import Testing
@testable import DesignSystem

@Suite struct FoodGroupTests {
    @Test func sixGroups() { #expect(FoodGroup.allCases.count == 6) }

    @Test(arguments: FoodGroup.allCases)
    func ringStandsOutFromGlobe(group: FoodGroup) {
        #expect(Contrast.ratio(group.ring.light, WorldPalette.globe.light) >= 3, "\(group) light")
        #expect(Contrast.ratio(group.ring.dark, WorldPalette.globe.dark) >= 3, "\(group) dark")
    }

    @Test func vegetablesAndProteinDifferInLightness() {
        // protan/deutan users confuse hue; lightness must separate these two neighbors
        let ratio = Contrast.ratio(FoodGroup.vegetables.fill, FoodGroup.protein.fill)
        #expect(ratio >= 1.5)
    }

    @Test func approvedFills() {
        #expect(FoodGroup.vegetables.fill == RGB(hex: 0x4F8A5B))
        #expect(FoodGroup.protein.fill == RGB(hex: 0x7E4127))
        #expect(FoodGroup.grains.fill == RGB(hex: 0xE2B54E))
    }
}
```
- [ ] **Step 2: RED.**
- [ ] **Step 3: Implement**

`FoodGroup.swift`:
```swift
/// The six food groups that make up a person's world. Their colors are reserved for the world and its legend.
public enum FoodGroup: String, CaseIterable, Codable, Sendable {
    case vegetables, fruit, grains, protein, legumesAndNuts, dairyAndAlternatives

    public var fill: RGB {
        switch self {
        case .vegetables: RGB(hex: 0x4F8A5B)
        case .fruit: RGB(hex: 0xD07A9A)
        case .grains: RGB(hex: 0xE2B54E)
        case .protein: RGB(hex: 0x7E4127)
        case .legumesAndNuts: RGB(hex: 0x8B7AC0)
        case .dairyAndAlternatives: RGB(hex: 0xF6F3EA)
        }
    }

    /// Ring that separates a place from the globe and its neighbors (≥3:1 against the globe in both themes).
    public var ring: ThemedColor {
        switch self {
        case .vegetables: ThemedColor(light: 0x2F5A39, dark: 0xA9D3B4)
        case .fruit: ThemedColor(light: 0x8E4766, dark: 0xF2B8CD)
        case .grains: ThemedColor(light: 0x8A6A1E, dark: 0xF4D78F)
        case .protein: ThemedColor(light: 0x4A2414, dark: 0xE0A88A)
        case .legumesAndNuts: ThemedColor(light: 0x5E4F94, dark: 0xC5BAE8)
        case .dairyAndAlternatives: ThemedColor(light: 0x7D7563, dark: 0xF6F3EA)
        }
    }
}

public enum WorldPalette {
    public static let globe = ThemedColor(light: 0xDCE9F1, dark: 0x22313A)
}
```
Note: the dairy ring is `#7D7563`, not the canvas's `#B5AE9C`, which measured 1.79:1. Record this in the report.

`Typography.swift`:
```swift
import SwiftUI

/// iOS text styles in SF Pro Rounded; all scale with Dynamic Type.
public extension Font {
    static let nuriLargeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let nuriTitle = Font.system(.title, design: .rounded, weight: .bold)
    static let nuriTitle2 = Font.system(.title2, design: .rounded, weight: .bold)
    static let nuriHeadline = Font.system(.headline, design: .rounded, weight: .bold)
    static let nuriBody = Font.system(.body, design: .rounded)
    static let nuriBodyEmphasis = Font.system(.body, design: .rounded, weight: .semibold)
    static let nuriSubheadline = Font.system(.subheadline, design: .rounded)
    static let nuriSubheadlineEmphasis = Font.system(.subheadline, design: .rounded, weight: .semibold)
    static let nuriFootnote = Font.system(.footnote, design: .rounded)
    static let nuriFootnoteEmphasis = Font.system(.footnote, design: .rounded, weight: .bold)
    static let nuriCaption = Font.system(.caption, design: .rounded)
}
```

`Metrics.swift`:
```swift
import CoreGraphics

public enum NuriMetrics {
    public static let screenMargin: CGFloat = 16
    public static let minTouch: CGFloat = 44
    public static let buttonHeight: CGFloat = 52
    public static let radiusControl: CGFloat = 12
    public static let radiusButton: CGFloat = 14
    public static let radiusCard: CGFloat = 16
}
```

`Color+Nuri.swift`:
```swift
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public extension Color {
    /// A dynamic color that follows the system light/dark appearance.
    init(_ themed: ThemedColor) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? themed.dark : themed.light
            return UIColor(red: c.red, green: c.green, blue: c.blue, alpha: 1)
        })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = isDark ? themed.dark : themed.light
            return NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 1)
        })
        #endif
    }

    init(_ rgb: RGB) { self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1) }

    static let nuriGround = Color(NuriPalette.ground)
    static let nuriSurface = Color(NuriPalette.surface)
    static let nuriInk = Color(NuriPalette.ink)
    static let nuriInkSoft = Color(NuriPalette.inkSoft)
    static let nuriTint = Color(NuriPalette.tint)
    static let nuriTintPressed = Color(NuriPalette.tintPressed)
    static let nuriOnTint = Color(NuriPalette.onTint)
    static let nuriProgress = Color(NuriPalette.progress)
    static let nuriTrack = Color(NuriPalette.track)
    static let nuriLink = Color(NuriPalette.link)
    static let nuriSeparator = Color(NuriPalette.separator)
    static let nuriFillSecondary = Color(NuriPalette.fillSecondary)
    static let nuriSand = Color(NuriPalette.sand)
    static let nuriVerified = Color(NuriPalette.verified)
    static let nuriManufacturer = Color(NuriPalette.manufacturer)
    static let nuriCommunity = Color(NuriPalette.community)
    static let nuriAdLabel = Color(NuriPalette.adLabel)
    static let nuriAdOutline = Color(NuriPalette.adOutline)
    static let nuriNotice = Color(NuriPalette.notice)
    static let nuriNoticeInk = Color(NuriPalette.noticeInk)
    static let nuriToast = Color(NuriPalette.toast)
    static let nuriOnToast = Color(NuriPalette.onToast)
    static let nuriToastAction = Color(NuriPalette.toastAction)
    static let nuriDisabledFill = Color(NuriPalette.disabledFill)
    static let nuriDisabledText = Color(NuriPalette.disabledText)
    static let nuriChevron = Color(NuriPalette.chevron)
}
```
- [ ] **Step 4: GREEN** (full package suite, no warnings; Swift 6 strict concurrency must be clean).
- [ ] **Step 5: Commit**: `feat(design): food groups, typography, metrics and dynamic colors`

---

### Task 4: World layout and WorldView (the signature)

**Files:**
- Create: `Sources/DesignSystem/World/WorldLayout.swift`, `Sources/DesignSystem/World/WorldView.swift`
- Test: `Tests/DesignSystemTests/WorldLayoutTests.swift`

**Interfaces:**
- Produces:
  - `WorldLayout.slot(for: FoodGroup) -> CGRect`, a unit-square rect in 0…1 where every group always lives in the same place.
  - `WorldView(today: [FoodGroup], resting: [FoodGroup], accessibilityLabel: Text)`, a square that fills its frame.
  - Groups in `today` are filled. Groups only in `resting` draw as dashed outlines. Others are absent.

- [ ] **Step 1: Failing tests**
```swift
import CoreGraphics
import Testing
@testable import DesignSystem

@Suite struct WorldLayoutTests {
    @Test(arguments: FoodGroup.allCases)
    func slotCenterSitsInsideTheGlobe(group: FoodGroup) {
        let r = WorldLayout.slot(for: group)
        let dx = r.midX - 0.5, dy = r.midY - 0.5
        #expect((dx * dx + dy * dy).squareRoot() <= 0.5 * 0.82, "\(group)")
        #expect(r.width > 0 && r.height > 0)
    }

    @Test func placesBarelyOverlap() {
        let groups = FoodGroup.allCases
        for i in groups.indices {
            for j in groups.indices where j > i {
                let a = WorldLayout.slot(for: groups[i]), b = WorldLayout.slot(for: groups[j])
                let overlap = a.intersection(b)
                let area = overlap.isNull ? 0 : overlap.width * overlap.height
                let smaller = min(a.width * a.height, b.width * b.height)
                #expect(area <= smaller * 0.15, "\(groups[i]) vs \(groups[j])")
            }
        }
    }

    @Test func eachGroupHasItsOwnPlace() {
        let centers = Set(FoodGroup.allCases.map { "\(WorldLayout.slot(for: $0).midX)-\(WorldLayout.slot(for: $0).midY)" })
        #expect(centers.count == 6)
    }
}
```
- [ ] **Step 2: RED.**
- [ ] **Step 3: Implement**

`WorldLayout.swift`:
```swift
import CoreGraphics

/// Fixed places on the world, from the approved board (196 pt reference globe).
public enum WorldLayout {
    static let reference: CGFloat = 196

    public static func slot(for group: FoodGroup) -> CGRect {
        let r: CGRect = switch group {
        case .vegetables: CGRect(x: 18, y: 44, width: 86, height: 64)
        case .grains: CGRect(x: 100, y: 24, width: 70, height: 52)
        case .protein: CGRect(x: 66, y: 112, width: 96, height: 58)
        case .fruit: CGRect(x: 146, y: 86, width: 40, height: 40)
        case .legumesAndNuts: CGRect(x: 26, y: 130, width: 34, height: 30)
        case .dairyAndAlternatives: CGRect(x: 40, y: 18, width: 40, height: 26)
        }
        return CGRect(x: r.minX / reference, y: r.minY / reference, width: r.width / reference, height: r.height / reference)
    }
}
```

`WorldView.swift`:
```swift
import SwiftUI

/// Nuri's signature: each food group eaten today is a place on a small world.
/// Groups from earlier in the week rest as outlines. Nothing shrinks; there is no count.
public struct WorldView: View {
    private let today: [FoodGroup]
    private let resting: [FoodGroup]
    private let label: Text
    @Environment(\.colorScheme) private var colorScheme

    public init(today: [FoodGroup], resting: [FoodGroup], accessibilityLabel: Text) {
        self.today = today
        self.resting = resting.filter { !today.contains($0) }
        self.label = accessibilityLabel
    }

    public var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack(alignment: .topLeading) {
                Circle().fill(Color(WorldPalette.globe))
                ForEach(FoodGroup.allCases, id: \.self) { group in
                    if today.contains(group) {
                        place(group, side: side, filled: true)
                    } else if resting.contains(group) {
                        place(group, side: side, filled: false)
                    }
                }
            }
            .frame(width: side, height: side)
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.12), radius: 12, y: 8)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private func place(_ group: FoodGroup, side: CGFloat, filled: Bool) -> some View {
        let r = WorldLayout.slot(for: group)
        let w = r.width * side, h = r.height * side
        let shape = UnevenRoundedRectangle(topLeadingRadius: h * 0.55, bottomLeadingRadius: h * 0.45,
                                           bottomTrailingRadius: h * 0.6, topTrailingRadius: h * 0.5, style: .continuous)
        let ring = colorScheme == .dark ? group.ring.dark : group.ring.light
        Group {
            if filled {
                shape.fill(Color(group.fill))
                    .overlay(shape.strokeBorder(Color(ring), lineWidth: 2))
                    .background(shape.stroke(Color.white, lineWidth: 3))
            } else {
                shape.fill(Color(group.fill).opacity(0.18))
                    .overlay(shape.strokeBorder(Color(ring), style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
            }
        }
        .frame(width: w, height: h)
        .offset(x: r.minX * side, y: r.minY * side)
    }
}

#Preview("World") {
    WorldView(today: [.vegetables, .grains, .protein, .fruit], resting: [.legumesAndNuts],
              accessibilityLabel: Text(verbatim: "Your world today"))
        .frame(width: 196, height: 196)
        .padding()
}
```
- [ ] **Step 4: GREEN** (package suite). Also run `swift build --package-path ios/Packages/NuriDesignSystem` and make sure it shows no warnings.
- [ ] **Step 5: Commit**: `feat(design): world layout and WorldView`

---

### Task 5: Components: buttons, card, progress, source label, notice, toast, ad card

**Files:**
- Create: `Sources/DesignSystem/Components/Buttons.swift`, `NuriCard.swift`, `ProgressBar.swift`, `SourceLabel.swift`, `NoticeCard.swift`, `Toast.swift`, `AdCard.swift`
- Test: `Tests/DesignSystemTests/ProgressBarTests.swift`, `Tests/DesignSystemTests/SourceLabelTests.swift`

**Interfaces:**
- Produces:
  - `NuriPrimaryButtonStyle()`, `NuriSecondaryButtonStyle()`, `NuriTextButtonStyle()`
  - `NuriCard { content }`
  - `NuriProgressBar(value:total:label:valueText:)` with static `fraction(value:total:) -> Double`
  - `SourceKind` (`verified manufacturer community userCreated photoEstimate`) with `symbolName` and `color: ThemedColor`
  - `SourceLabel(_ kind:, title: Text, accessibilityLabel: Text)`
  - `NoticeCard(title:message:actionTitle:action:)`
  - `NuriToast(message:actionTitle:action:)`
  - `AdCard(label:title:subtitle:ctaTitle:onOpen:onWhy:)`

- [ ] **Step 1: Failing tests**
```swift
import Testing
@testable import DesignSystem

@Suite struct ProgressBarTests {
    @Test func fractionClamps() {
        #expect(NuriProgressBar.fraction(value: 1240, total: 2000) == 0.62)
        #expect(NuriProgressBar.fraction(value: 2120, total: 2000) == 1)
        #expect(NuriProgressBar.fraction(value: -5, total: 2000) == 0)
        #expect(NuriProgressBar.fraction(value: 10, total: 0) == 0)
        #expect(NuriProgressBar.fraction(value: .nan, total: 100) == 0)
    }
}

@Suite struct SourceLabelTests {
    @Test(arguments: SourceKind.allCases)
    func everyKindHasSymbolAndReadableColor(kind: SourceKind) {
        #expect(!kind.symbolName.isEmpty)
        #expect(Contrast.ratio(kind.color.light, NuriPalette.surface.light) >= 4.5)
        #expect(Contrast.ratio(kind.color.dark, NuriPalette.surface.dark) >= 4.5)
    }
}
```
- [ ] **Step 2: RED.**
- [ ] **Step 3: Implement**

`Buttons.swift`:
```swift
import SwiftUI

public struct NuriPrimaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { PrimaryBody(configuration: configuration) }

    private struct PrimaryBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled
        var body: some View {
            configuration.label
                .font(.nuriHeadline)
                .foregroundStyle(isEnabled ? Color.nuriOnTint : Color.nuriDisabledText)
                .frame(maxWidth: .infinity, minHeight: NuriMetrics.buttonHeight)
                .padding(.horizontal, 16)
                .background(background, in: RoundedRectangle(cornerRadius: NuriMetrics.radiusButton, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: NuriMetrics.radiusButton, style: .continuous))
        }
        private var background: Color {
            guard isEnabled else { return .nuriDisabledFill }
            return configuration.isPressed ? .nuriTintPressed : .nuriTint
        }
    }
}

public struct NuriSecondaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nuriSubheadlineEmphasis)
            .foregroundStyle(Color.nuriInk)
            .frame(minHeight: NuriMetrics.minTouch)
            .padding(.horizontal, 16)
            .background(Color.nuriFillSecondary.opacity(configuration.isPressed ? 0.7 : 1),
                        in: RoundedRectangle(cornerRadius: NuriMetrics.radiusControl, style: .continuous))
            .contentShape(Rectangle())
    }
}

public struct NuriTextButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nuriSubheadlineEmphasis)
            .foregroundStyle(Color.nuriTint.opacity(configuration.isPressed ? 0.6 : 1))
            .frame(minHeight: NuriMetrics.minTouch)
            .contentShape(Rectangle())
    }
}
```

`NuriCard.swift`:
```swift
import SwiftUI

/// The white grouped surface used for lists and summaries.
public struct NuriCard<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.nuriSurface, in: RoundedRectangle(cornerRadius: NuriMetrics.radiusCard, style: .continuous))
    }
}
```

`ProgressBar.swift`:
```swift
import SwiftUI

/// Calm, always-blue progress. Over 100% stays the same color: a guide, not a limit.
public struct NuriProgressBar: View {
    private let fraction: Double
    private let label: Text
    private let valueText: Text

    public init(value: Double, total: Double, label: Text, valueText: Text) {
        self.fraction = Self.fraction(value: value, total: total)
        self.label = label
        self.valueText = valueText
    }

    public static func fraction(value: Double, total: Double) -> Double {
        guard value.isFinite, total.isFinite, total > 0 else { return 0 }
        return min(1, max(0, value / total))
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.nuriTrack)
                Capsule().fill(Color.nuriProgress).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(valueText)
    }
}
```

`SourceLabel.swift`:
```swift
import SwiftUI

public enum SourceKind: String, CaseIterable, Sendable {
    case verified, manufacturer, community, userCreated, photoEstimate

    public var symbolName: String {
        switch self {
        case .verified: "checkmark.shield"
        case .manufacturer: "building.2"
        case .community: "person.2"
        case .userCreated: "person"
        case .photoEstimate: "camera"
        }
    }

    public var color: ThemedColor {
        switch self {
        case .verified: NuriPalette.verified
        case .manufacturer: NuriPalette.manufacturer
        case .community: NuriPalette.community
        case .userCreated, .photoEstimate: NuriPalette.inkSoft
        }
    }
}

/// Where a food's numbers come from. Icon + text, never color alone.
public struct SourceLabel: View {
    private let kind: SourceKind
    private let title: Text
    private let spoken: Text

    public init(_ kind: SourceKind, title: Text, accessibilityLabel: Text) {
        self.kind = kind
        self.title = title
        self.spoken = accessibilityLabel
    }

    public var body: some View {
        Label { title } icon: { Image(systemName: kind.symbolName) }
            .labelStyle(.titleAndIcon)
            .font(.nuriFootnoteEmphasis)
            .foregroundStyle(Color(kind.color))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spoken)
    }
}
```

`NoticeCard.swift`:
```swift
import SwiftUI

/// A gentle notice (e.g. clinician suggestion, feature not ready yet). Never alarming.
public struct NoticeCard: View {
    private let title: Text
    private let message: Text
    private let actionTitle: Text?
    private let action: (() -> Void)?

    public init(title: Text, message: Text, actionTitle: Text? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "heart").font(.nuriHeadline).foregroundStyle(Color.nuriNoticeInk).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                title.font(.nuriSubheadlineEmphasis)
                message.font(.nuriFootnote)
                if let actionTitle, let action {
                    Button(action: action) { actionTitle }
                        .buttonStyle(.plain)
                        .font(.nuriFootnoteEmphasis)
                        .foregroundStyle(Color.nuriLink)
                        .frame(minHeight: NuriMetrics.minTouch, alignment: .leading)
                }
            }
            .foregroundStyle(Color.nuriNoticeInk)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.nuriNotice, in: RoundedRectangle(cornerRadius: NuriMetrics.radiusCard, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
```

`Toast.swift`:
```swift
import SwiftUI

/// Confirmation with an undo, e.g. "Added to lunch · Undo".
public struct NuriToast: View {
    private let message: Text
    private let actionTitle: Text
    private let action: () -> Void

    public init(message: Text, actionTitle: Text, action: @escaping () -> Void) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.nuriToastAction).accessibilityHidden(true)
            message.font(.nuriSubheadlineEmphasis).foregroundStyle(Color.nuriOnToast)
            Spacer(minLength: 8)
            Button(action: action) { actionTitle }
                .buttonStyle(.plain)
                .font(.nuriSubheadlineEmphasis)
                .foregroundStyle(Color.nuriToastAction)
                .frame(minWidth: NuriMetrics.minTouch, minHeight: NuriMetrics.minTouch)
        }
        .padding(.leading, 14).padding(.trailing, 6).padding(.vertical, 4)
        .background(Color.nuriToast, in: RoundedRectangle(cornerRadius: NuriMetrics.radiusButton, style: .continuous))
    }
}
```

`AdCard.swift`:
```swift
import SwiftUI

/// An ad. Label first ("Ad · Partner" / "광고 · Partner"), solid neutral outline, a 44 pt "Why this ad" button.
/// Callers must never show this when numbers are hidden or next to totals.
public struct AdCard: View {
    private let label: Text
    private let title: Text
    private let subtitle: Text
    private let ctaTitle: Text
    private let onOpen: () -> Void
    private let onWhy: () -> Void

    public init(label: Text, title: Text, subtitle: Text, ctaTitle: Text, onOpen: @escaping () -> Void, onWhy: @escaping () -> Void) {
        self.label = label
        self.title = title
        self.subtitle = subtitle
        self.ctaTitle = ctaTitle
        self.onOpen = onOpen
        self.onWhy = onWhy
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                label.font(.nuriFootnoteEmphasis).foregroundStyle(Color.nuriAdLabel)
                Spacer()
                Button(action: onWhy) { Image(systemName: "info.circle") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.nuriInkSoft)
                    .frame(width: NuriMetrics.minTouch, height: NuriMetrics.minTouch)
                    .accessibilityLabel(Text("Why this ad, and hide options", bundle: .module))
            }
            title.font(.nuriHeadline).foregroundStyle(Color.nuriInk)
            subtitle.font(.nuriFootnote).foregroundStyle(Color.nuriInkSoft)
            Button(action: onOpen) {
                HStack(spacing: 6) { ctaTitle; Image(systemName: "arrow.up.right.square").accessibilityHidden(true) }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NuriSecondaryButtonStyle())
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color.nuriSurface, in: RoundedRectangle(cornerRadius: NuriMetrics.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NuriMetrics.radiusCard, style: .continuous).strokeBorder(Color.nuriAdOutline, lineWidth: 1.5))
    }
}
```
`AdCard` uses one package-owned string. Add `Sources/DesignSystem/Resources/Localizable.xcstrings` with the key `Why this ad, and hide options` (ko: `이 광고가 표시되는 이유와 숨기기 옵션`), add `defaultLocalization: "en"` to `Package.swift`, and add `resources: [.process("Resources")]` to the `DesignSystem` target.

String Catalog JSON shape (use it for every catalog in this plan):
```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "Why this ad, and hide options" : {
      "localizations" : {
        "ko" : { "stringUnit" : { "state" : "translated", "value" : "이 광고가 표시되는 이유와 숨기기 옵션" } }
      }
    }
  },
  "version" : "1.0"
}
```
- [ ] **Step 4: GREEN** (`swift test --package-path ios/Packages/NuriDesignSystem`, no warnings).
- [ ] **Step 5: Commit**: `feat(design): core components`

---

### Task 6: Xcode project, app skeleton, assets, CI

**Files:**
- Create: `ios/Nuri.xcodeproj/project.pbxproj` (below)
- Create: `ios/App/NuriApp.swift` (temporary: `WindowGroup { Text(verbatim: "Nuri") }`; replaced in Task 7), `ios/App/Assets.xcassets/Contents.json`, `ios/App/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `ios/NuriTests/SmokeTests.swift`, `ios/NuriUITests/LaunchUITests.swift`
- Create: `.github/workflows/ios.yml`
- Modify: `.gitignore` (add `build/`)

- [ ] **Step 1: Write `ios/Nuri.xcodeproj/project.pbxproj`.** This format was proven on Xcode 27: synchronized folders, local packages, and a hosted test bundle. Copy it exactly.

```
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 77;
	objects = {

/* Begin PBXBuildFile section */
		A10000000000000000000101 /* NuriDomain in Frameworks */ = {isa = PBXBuildFile; productRef = A10000000000000000000201 /* NuriDomain */; };
		A10000000000000000000102 /* NutritionEngine in Frameworks */ = {isa = PBXBuildFile; productRef = A10000000000000000000202 /* NutritionEngine */; };
		A10000000000000000000103 /* ActivityEngine in Frameworks */ = {isa = PBXBuildFile; productRef = A10000000000000000000203 /* ActivityEngine */; };
		A10000000000000000000104 /* DesignSystem in Frameworks */ = {isa = PBXBuildFile; productRef = A10000000000000000000204 /* DesignSystem */; };
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		A10000000000000000000301 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = A10000000000000000000001 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = A10000000000000000000010;
			remoteInfo = Nuri;
		};
		A10000000000000000000302 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = A10000000000000000000001 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = A10000000000000000000010;
			remoteInfo = Nuri;
		};
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
		A10000000000000000000020 /* Nuri.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Nuri.app; sourceTree = BUILT_PRODUCTS_DIR; };
		A10000000000000000000021 /* NuriTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = NuriTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
		A10000000000000000000022 /* NuriUITests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = NuriUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		A10000000000000000000030 /* App */ = {isa = PBXFileSystemSynchronizedRootGroup; path = App; sourceTree = "<group>"; };
		A10000000000000000000031 /* NuriTests */ = {isa = PBXFileSystemSynchronizedRootGroup; path = NuriTests; sourceTree = "<group>"; };
		A10000000000000000000032 /* NuriUITests */ = {isa = PBXFileSystemSynchronizedRootGroup; path = NuriUITests; sourceTree = "<group>"; };
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
		A10000000000000000000040 /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (A10000000000000000000101 /* NuriDomain in Frameworks */, A10000000000000000000102 /* NutritionEngine in Frameworks */, A10000000000000000000103 /* ActivityEngine in Frameworks */, A10000000000000000000104 /* DesignSystem in Frameworks */,); runOnlyForDeploymentPostprocessing = 0; };
		A10000000000000000000041 /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
		A10000000000000000000042 /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		A10000000000000000000050 = {
			isa = PBXGroup;
			children = (
				A10000000000000000000030 /* App */,
				A10000000000000000000031 /* NuriTests */,
				A10000000000000000000032 /* NuriUITests */,
				A10000000000000000000051 /* Products */,
			);
			sourceTree = "<group>";
		};
		A10000000000000000000051 /* Products */ = {
			isa = PBXGroup;
			children = (
				A10000000000000000000020 /* Nuri.app */,
				A10000000000000000000021 /* NuriTests.xctest */,
				A10000000000000000000022 /* NuriUITests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		A10000000000000000000010 /* Nuri */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = A10000000000000000000070;
			buildPhases = (
				A10000000000000000000060 /* Sources */,
				A10000000000000000000040 /* Frameworks */,
				A10000000000000000000063 /* Resources */,
			);
			buildRules = ();
			dependencies = ();
			fileSystemSynchronizedGroups = (A10000000000000000000030 /* App */,);
			name = Nuri;
			packageProductDependencies = (A10000000000000000000201 /* NuriDomain */, A10000000000000000000202 /* NutritionEngine */, A10000000000000000000203 /* ActivityEngine */, A10000000000000000000204 /* DesignSystem */,);
			productName = Nuri;
			productReference = A10000000000000000000020 /* Nuri.app */;
			productType = "com.apple.product-type.application";
		};
		A10000000000000000000011 /* NuriTests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = A10000000000000000000071;
			buildPhases = (
				A10000000000000000000061 /* Sources */,
				A10000000000000000000041 /* Frameworks */,
				A10000000000000000000064 /* Resources */,
			);
			buildRules = ();
			dependencies = (A10000000000000000000401 /* PBXTargetDependency */,);
			fileSystemSynchronizedGroups = (A10000000000000000000031 /* NuriTests */,);
			name = NuriTests;
			packageProductDependencies = ();
			productName = NuriTests;
			productReference = A10000000000000000000021 /* NuriTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		};
		A10000000000000000000012 /* NuriUITests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = A10000000000000000000072;
			buildPhases = (
				A10000000000000000000062 /* Sources */,
				A10000000000000000000042 /* Frameworks */,
				A10000000000000000000065 /* Resources */,
			);
			buildRules = ();
			dependencies = (A10000000000000000000402 /* PBXTargetDependency */,);
			fileSystemSynchronizedGroups = (A10000000000000000000032 /* NuriUITests */,);
			name = NuriUITests;
			packageProductDependencies = ();
			productName = NuriUITests;
			productReference = A10000000000000000000022 /* NuriUITests.xctest */;
			productType = "com.apple.product-type.bundle.ui-testing";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		A10000000000000000000001 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2700;
				LastUpgradeCheck = 2700;
				TargetAttributes = {
					A10000000000000000000010 = {CreatedOnToolsVersion = 27.0;};
					A10000000000000000000011 = {CreatedOnToolsVersion = 27.0; TestTargetID = A10000000000000000000010;};
					A10000000000000000000012 = {CreatedOnToolsVersion = 27.0; TestTargetID = A10000000000000000000010;};
				};
			};
			buildConfigurationList = A10000000000000000000073;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (en, ko, Base,);
			mainGroup = A10000000000000000000050;
			minimizedProjectReferenceProxies = 1;
			packageReferences = (A10000000000000000000501 /* XCLocalSwiftPackageReference "Packages/NuriEngines" */, A10000000000000000000502 /* XCLocalSwiftPackageReference "Packages/NuriDesignSystem" */,);
			preferredProjectObjectVersion = 77;
			productRefGroup = A10000000000000000000051 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (A10000000000000000000010 /* Nuri */, A10000000000000000000011 /* NuriTests */, A10000000000000000000012 /* NuriUITests */,);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		A10000000000000000000063 /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
		A10000000000000000000064 /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
		A10000000000000000000065 /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		A10000000000000000000060 /* Sources */ = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
		A10000000000000000000061 /* Sources */ = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
		A10000000000000000000062 /* Sources */ = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		A10000000000000000000401 /* PBXTargetDependency */ = {isa = PBXTargetDependency; target = A10000000000000000000010 /* Nuri */; targetProxy = A10000000000000000000301 /* PBXContainerItemProxy */;};
		A10000000000000000000402 /* PBXTargetDependency */ = {isa = PBXTargetDependency; target = A10000000000000000000010 /* Nuri */; targetProxy = A10000000000000000000302 /* PBXContainerItemProxy */;};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		A10000000000000000000080 /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {ALWAYS_SEARCH_USER_PATHS = NO; ENABLE_TESTABILITY = YES; IPHONEOS_DEPLOYMENT_TARGET = 17.0; ONLY_ACTIVE_ARCH = YES; SDKROOT = iphoneos; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)"; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; DEBUG_INFORMATION_FORMAT = dwarf; GCC_OPTIMIZATION_LEVEL = 0; LOCALIZATION_PREFERS_STRING_CATALOGS = YES;}; name = Debug;};
		A10000000000000000000081 /* Release */ = {isa = XCBuildConfiguration; buildSettings = {ALWAYS_SEARCH_USER_PATHS = NO; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; SWIFT_COMPILATION_MODE = wholemodule; VALIDATE_PRODUCT = YES; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"; LOCALIZATION_PREFERS_STRING_CATALOGS = YES;}; name = Release;};
		A10000000000000000000082 /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; ENABLE_PREVIEWS = YES; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_CFBundleDisplayName = Nuri; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks"; MARKETING_VERSION = 0.1.0; PRODUCT_BUNDLE_IDENTIFIER = app.nuri.ios; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_EMIT_LOC_STRINGS = YES; SWIFT_VERSION = 6.0; TARGETED_DEVICE_FAMILY = 1;}; name = Debug;};
		A10000000000000000000083 /* Release */ = {isa = XCBuildConfiguration; buildSettings = {ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; ENABLE_PREVIEWS = YES; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_CFBundleDisplayName = Nuri; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks"; MARKETING_VERSION = 0.1.0; PRODUCT_BUNDLE_IDENTIFIER = app.nuri.ios; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_EMIT_LOC_STRINGS = YES; SWIFT_VERSION = 6.0; TARGETED_DEVICE_FAMILY = 1;}; name = Release;};
		A10000000000000000000084 /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {BUNDLE_LOADER = "$(TEST_HOST)"; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = app.nuri.ios.tests; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 6.0; TARGETED_DEVICE_FAMILY = 1; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Nuri.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Nuri";}; name = Debug;};
		A10000000000000000000085 /* Release */ = {isa = XCBuildConfiguration; buildSettings = {BUNDLE_LOADER = "$(TEST_HOST)"; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = app.nuri.ios.tests; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 6.0; TARGETED_DEVICE_FAMILY = 1; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Nuri.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Nuri";}; name = Release;};
		A10000000000000000000086 /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = app.nuri.ios.uitests; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 6.0; TARGETED_DEVICE_FAMILY = 1; TEST_TARGET_NAME = Nuri;}; name = Debug;};
		A10000000000000000000087 /* Release */ = {isa = XCBuildConfiguration; buildSettings = {GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = app.nuri.ios.uitests; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 6.0; TARGETED_DEVICE_FAMILY = 1; TEST_TARGET_NAME = Nuri;}; name = Release;};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		A10000000000000000000070 = {isa = XCConfigurationList; buildConfigurations = (A10000000000000000000082, A10000000000000000000083,); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;};
		A10000000000000000000071 = {isa = XCConfigurationList; buildConfigurations = (A10000000000000000000084, A10000000000000000000085,); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;};
		A10000000000000000000072 = {isa = XCConfigurationList; buildConfigurations = (A10000000000000000000086, A10000000000000000000087,); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;};
		A10000000000000000000073 = {isa = XCConfigurationList; buildConfigurations = (A10000000000000000000080, A10000000000000000000081,); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;};
/* End XCConfigurationList section */

/* Begin XCLocalSwiftPackageReference section */
		A10000000000000000000501 /* XCLocalSwiftPackageReference "Packages/NuriEngines" */ = {isa = XCLocalSwiftPackageReference; relativePath = Packages/NuriEngines; };
		A10000000000000000000502 /* XCLocalSwiftPackageReference "Packages/NuriDesignSystem" */ = {isa = XCLocalSwiftPackageReference; relativePath = Packages/NuriDesignSystem; };
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		A10000000000000000000201 /* NuriDomain */ = {isa = XCSwiftPackageProductDependency; productName = NuriDomain; };
		A10000000000000000000202 /* NutritionEngine */ = {isa = XCSwiftPackageProductDependency; productName = NutritionEngine; };
		A10000000000000000000203 /* ActivityEngine */ = {isa = XCSwiftPackageProductDependency; productName = ActivityEngine; };
		A10000000000000000000204 /* DesignSystem */ = {isa = XCSwiftPackageProductDependency; productName = DesignSystem; };
/* End XCSwiftPackageProductDependency section */
	};
	rootObject = A10000000000000000000001 /* Project object */;
}
```
`PRODUCT_BUNDLE_IDENTIFIER = app.nuri.ios` is a placeholder until the Apple Developer account exists. Record that in the report.

- [ ] **Step 2: Skeleton files**

`ios/App/NuriApp.swift` (temporary):
```swift
import SwiftUI

@main
struct NuriApp: App {
    var body: some Scene { WindowGroup { Text(verbatim: "Nuri") } }
}
```
`ios/App/Assets.xcassets/Contents.json`: `{"info":{"author":"xcode","version":1}}`
`ios/App/Assets.xcassets/AccentColor.colorset/Contents.json`:
```json
{
  "colors" : [
    { "color" : { "color-space" : "srgb", "components" : { "alpha" : "1.000", "red" : "0x3B", "green" : "0x6A", "blue" : "0x4A" } }, "idiom" : "universal" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "color" : { "color-space" : "srgb", "components" : { "alpha" : "1.000", "red" : "0x7F", "green" : "0xB5", "blue" : "0x8A" } }, "idiom" : "universal" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```
`ios/NuriTests/SmokeTests.swift`:
```swift
import Testing
@testable import Nuri

@Test func appModuleLoads() { #expect(Bool(true)) }
```
`ios/NuriUITests/LaunchUITests.swift`:
```swift
import XCTest

final class LaunchUITests: XCTestCase {
    @MainActor
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
    }
}
```
- [ ] **Step 3: Build and test.** Run the app test command from the Global Constraints. Expected: `** TEST SUCCEEDED **`, with the smoke test and the launch UI test passing. Filter the noise with `| grep -E "error|warning: |TEST SUCCEEDED|TEST FAILED" | grep -v appintents`. The only allowed warning is Apple's `appintentsmetadataprocessor` notice.
- [ ] **Step 4: CI workflow** `.github/workflows/ios.yml`:
```yaml
name: ios
on:
  pull_request:
  push:
    branches: [main]
jobs:
  design-system:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - run: swift test --package-path ios/Packages/NuriDesignSystem
  app:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Pick a simulator
        run: echo "DEVICE=$(xcrun simctl list devices available | grep -m1 -oE 'iPhone [0-9]+( Pro)?' )" >> "$GITHUB_ENV"
      - name: Test app
        run: xcodebuild test -project ios/Nuri.xcodeproj -scheme Nuri -destination "platform=iOS Simulator,name=$DEVICE" -derivedDataPath build/DerivedData
```
Add `build/` to `.gitignore`.
- [ ] **Step 5: Commit**: `feat(app): Xcode project with local packages, tests and CI`

---

### Task 7: AppState, AuthService, EmailValidator

**Files:**
- Create: `ios/App/AppState.swift`, `ios/App/AuthService.swift`, `ios/App/EmailValidator.swift`
- Test: `ios/NuriTests/AppStateTests.swift`, `ios/NuriTests/EmailValidatorTests.swift` (delete `SmokeTests.swift`)

**Interfaces:**
- Produces:
  - `OnboardingStage {welcome, consent, complete}`
  - `ConsentError {adultRequired, healthDataRequired}`
  - `ConsentRecord`
  - `@MainActor @Observable final class AppState`, with `init(defaults:)`, `stage`, `consent`, `hideNumbers`, `chooseGuest()`, `recordConsent(adult:healthData:analytics:now:) throws(ConsentError)`, `setHideNumbers(_:)`, `startOver()`, and `static consentVersion`.
  - `SignInMethod`, `AuthAvailability`, `protocol AuthService`, `struct UnavailableAuthService`.
  - `EmailValidator.isPlausible(_:)`

- [ ] **Step 1: Failing tests**

`AppStateTests.swift`:
```swift
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
```

`EmailValidatorTests.swift`:
```swift
import Testing
@testable import Nuri

@Suite struct EmailValidatorTests {
    @Test(arguments: ["you@example.com", "a@b.co", "  you@example.com  ", "first.last+tag@sub.example.org"])
    func plausible(_ text: String) { #expect(EmailValidator.isPlausible(text)) }

    @Test(arguments: ["", "no-at.com", "a@b", "a@.com", "a b@c.com", "a@@b.com", "@example.com", "a@b.c"])
    func notPlausible(_ text: String) { #expect(!EmailValidator.isPlausible(text)) }
}
```
- [ ] **Step 2: RED** (app test command).
- [ ] **Step 3: Implement**

`AppState.swift`:
```swift
import Foundation
import Observation

enum OnboardingStage: String, Sendable {
    case welcome, consent, complete
}

enum ConsentError: Error, Equatable, Sendable {
    case adultRequired, healthDataRequired
}

/// What the person agreed to, when, and under which consent text version (PIPA record keeping).
struct ConsentRecord: Codable, Equatable, Sendable {
    let adultConfirmed: Bool
    let healthDataConsented: Bool
    let analyticsOptIn: Bool
    let consentVersion: String
    let recordedAt: Date
}

@MainActor
@Observable
final class AppState {
    static let consentVersion = "2026-10-08"

    private enum Keys {
        static let stage = "onboarding.stage"
        static let consent = "consent.record"
        static let hideNumbers = "display.hideNumbers"
    }

    @ObservationIgnored private let defaults: UserDefaults
    private(set) var stage: OnboardingStage
    private(set) var consent: ConsentRecord?
    private(set) var hideNumbers: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let consent = defaults.data(forKey: Keys.consent).flatMap { try? JSONDecoder().decode(ConsentRecord.self, from: $0) }
        let stored = defaults.string(forKey: Keys.stage).flatMap(OnboardingStage.init(rawValue:)) ?? .welcome
        self.consent = consent
        self.stage = (stored == .complete && consent == nil) ? .welcome : stored
        self.hideNumbers = defaults.bool(forKey: Keys.hideNumbers)
    }

    func chooseGuest() { setStage(.consent) }

    func recordConsent(adult: Bool, healthData: Bool, analytics: Bool, now: Date = .now) throws(ConsentError) {
        guard adult else { throw .adultRequired }
        guard healthData else { throw .healthDataRequired }
        let record = ConsentRecord(adultConfirmed: true, healthDataConsented: true, analyticsOptIn: analytics,
                                   consentVersion: Self.consentVersion, recordedAt: now)
        if let data = try? JSONEncoder().encode(record) { defaults.set(data, forKey: Keys.consent) }
        consent = record
        setStage(.complete)
    }

    func setHideNumbers(_ hidden: Bool) {
        hideNumbers = hidden
        defaults.set(hidden, forKey: Keys.hideNumbers)
    }

    func startOver() {
        for key in [Keys.stage, Keys.consent, Keys.hideNumbers] { defaults.removeObject(forKey: key) }
        consent = nil
        hideNumbers = false
        stage = .welcome
    }

    private func setStage(_ newStage: OnboardingStage) {
        stage = newStage
        defaults.set(newStage.rawValue, forKey: Keys.stage)
    }
}
```

`AuthService.swift`:
```swift
enum SignInMethod: String, CaseIterable, Sendable {
    case apple, google, email
}

enum AuthAvailability: Equatable, Sendable {
    case available, comingLater
}

/// Account sign-in (Supabase + Sign in with Apple/Google) arrives in the accounts phase.
protocol AuthService: Sendable {
    func availability(for method: SignInMethod) -> AuthAvailability
}

/// This build has no account backend. Nuri works fully without an account.
struct UnavailableAuthService: AuthService {
    func availability(for method: SignInMethod) -> AuthAvailability { .comingLater }
}
```

`EmailValidator.swift`:
```swift
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
```
- [ ] **Step 4: GREEN.**
- [ ] **Step 5: Commit**: `feat(app): app state with consent records, auth placeholder, email check`

---

### Task 8: String Catalog (EN/KO) + copy lint

**Files:**
- Create: `ios/App/Localizable.xcstrings`
- Create: `scripts/lint_copy.py`, `scripts/test_lint_copy.py`
- Modify: `.github/workflows/ios.yml` (add `copy-lint` job)

**Interfaces:**
- Produces: every user-facing key used by Tasks 9–10, in English and Korean. Views use these exact English strings as keys (`Text("Add food")`).

- [ ] **Step 1: Failing lint tests** `scripts/test_lint_copy.py`:
```python
import json
import os
import tempfile
import unittest

from lint_copy import scan


def catalog(strings):
    data = {"sourceLanguage": "en", "version": "1.0", "strings": {
        key: {"localizations": {"ko": {"stringUnit": {"state": "translated", "value": ko}}}} for key, ko in strings.items()
    }}
    f = tempfile.NamedTemporaryFile("w", suffix=".xcstrings", delete=False)
    json.dump(data, f, ensure_ascii=False)
    f.close()
    return f.name


class LintCopyTests(unittest.TestCase):
    def tearDown(self):
        for p in getattr(self, "paths", []):
            os.unlink(p)

    def run_scan(self, strings):
        p = catalog(strings)
        self.paths = [p]
        return scan(p)

    def test_clean_copy_passes(self):
        self.assertEqual(self.run_scan({"Add food": "음식 추가", "A guide, not a limit.": "한도가 아니라 가이드예요."}), [])

    def test_english_banned_phrases(self):
        found = self.run_scan({"Burn it off with a run": "달리기", "Cheat day": "자유식", "Guilt-free snack": "간식"})
        self.assertEqual(len(found), 3)

    def test_korean_banned_phrases(self):
        found = self.run_scan({"Snack": "죄책감 없는 간식"})
        self.assertEqual(len(found), 1)

    def test_word_boundaries(self):
        # "learn" and "Earnings" must not trip the "earn" rule
        self.assertEqual(self.run_scan({"Learn more": "더 알아보기"}), [])


if __name__ == "__main__":
    unittest.main()
```
- [ ] **Step 2: RED**: `cd scripts && python3 -m unittest test_lint_copy -v` (ImportError).
- [ ] **Step 3: Implement** `scripts/lint_copy.py`:
```python
#!/usr/bin/env python3
"""Fails when user-facing copy moralizes food or frames exercise as compensation (spec §4, design direction)."""
import json
import re
import sys

BANNED = [
    r"\bcheat(ing)?\b", r"\bguilt(y|-free)?\b", r"\bearn(ed|s)?\b", r"\bburn (it )?off\b", r"\bwork it off\b",
    r"\bskinny\b", r"\bdetox\b", r"\bcleanse\b", r"\b(good|bad|junk) foods?\b", r"\bsinful\b",
    r"\bover budget\b", r"\byou failed\b", r"\bmust exercise\b", r"\bbefore and after\b",
    "치팅", "죄책감", "보상 운동", "살 빼", "다이어트 실패", "디톡스",
]
PATTERNS = [re.compile(p, re.IGNORECASE) for p in BANNED]


def _texts(entry):
    for loc in entry.get("localizations", {}).values():
        unit = loc.get("stringUnit")
        if unit:
            yield unit.get("value", "")
        for variation in loc.get("variations", {}).values():
            for case in variation.values():
                yield case.get("stringUnit", {}).get("value", "")


def scan(path):
    with open(path, encoding="utf-8") as f:
        catalog = json.load(f)
    findings = []
    for key, entry in catalog.get("strings", {}).items():
        for text in [key, *_texts(entry)]:
            for pattern in PATTERNS:
                if pattern.search(text):
                    findings.append((key, text, pattern.pattern))
    return findings


def main(argv):
    paths = argv[1:] or ["ios/App/Localizable.xcstrings"]
    findings = [f for p in paths for f in scan(p)]
    for key, text, pattern in findings:
        print(f"banned copy ({pattern}): key={key!r} text={text!r}")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```
- [ ] **Step 4: Create `ios/App/Localizable.xcstrings`** with **exactly** these keys and Korean values (`state: translated`), using the JSON shape from Task 5. Generate it with a throwaway Python snippet from this table; do not commit the snippet.

| English key | Korean |
|---|---|
| An illustrated world of food groups | 음식 그룹으로 그려진 작은 세계 |
| Food and movement, gently | 음식과 움직임을 부드럽게 |
| Log meals, watch your world grow, and get a plan that fits your week. Your data stays yours. | 식사를 기록하고, 나만의 세계가 자라는 것을 보고, 내 한 주에 맞는 계획을 받아 보세요. 내 데이터는 나의 것이에요. |
| Continue with Apple | Apple로 계속하기 |
| Continue with Google | Google로 계속하기 |
| Continue with email | 이메일로 계속하기 |
| Use without an account | 계정 없이 사용하기 |
| For adults 18 and over. By continuing you agree to the Terms and Privacy Policy. | 만 18세 이상 성인을 위한 앱이에요. 계속하면 이용약관과 개인정보 처리방침에 동의하게 돼요. |
| Account sign-in arrives in a later build | 계정 로그인은 다음 버전에서 제공돼요 |
| You can use Nuri without an account now and add one later. | 지금은 계정 없이 누리를 사용하고 나중에 계정을 추가할 수 있어요. |
| OK | 확인 |
| Sign in with email | 이메일로 로그인 |
| We will send a 6-digit code. No password to remember. | 6자리 코드를 보내 드려요. 비밀번호는 필요 없어요. |
| Email | 이메일 |
| you@example.com | you@example.com |
| Send code | 코드 보내기 |
| Email sign-in arrives in a later build. You can use Nuri without an account now. | 이메일 로그인은 다음 버전에서 제공돼요. 지금은 계정 없이 누리를 사용할 수 있어요. |
| Before you start | 시작하기 전에 |
| Required | 필수 |
| Optional | 선택 |
| I am 18 or older | 만 18세 이상이에요 |
| Nuri is made for adults. | 누리는 성인을 위한 앱이에요. |
| Store my food and activity data | 음식 및 활동 데이터 저장 |
| Needed to run Nuri. This is health information, kept private and never sold or used for ads. Export or delete it anytime. | 누리를 사용하려면 필요해요. 건강 정보이므로 비공개로 보관하며 판매하거나 광고에 사용하지 않아요. 언제든 내보내거나 삭제할 수 있어요. |
| What we store and why | 저장하는 정보와 이유 |
| Share anonymous usage stats | 익명 사용 통계 공유 |
| Helps improve Nuri. Never includes foods, notes or health data. | 누리 개선에 도움이 돼요. 음식, 메모, 건강 데이터는 절대 포함되지 않아요. |
| Nuri gives general wellness estimates, not medical advice. Food energy, nutrients and exercise vary by person, preparation and device. For medical or nutrition guidance, talk to a qualified clinician. | 누리는 일반적인 웰니스 추정치를 제공하며 의학적 조언이 아니에요. 음식의 열량과 영양소, 운동량은 사람, 조리 방법, 기기에 따라 달라요. 의학적 또는 영양 관련 조언은 자격을 갖춘 전문가와 상담하세요. |
| Continue | 계속 |
| Turn on the two required items to continue. | 계속하려면 필수 항목 두 개를 켜 주세요. |
| Foods and meals you add | 추가한 음식과 식사 |
| To show your day, your world and your history. | 하루, 나의 세계, 기록을 보여 드리기 위해서예요. |
| Activity you log or import | 기록하거나 가져온 활동 |
| To suggest a plan that fits your week. | 내 한 주에 맞는 계획을 제안하기 위해서예요. |
| Your profile | 프로필 |
| Age, height and weight, only to estimate your daily guide. | 나이, 키, 몸무게는 하루 가이드를 추정하는 데에만 사용해요. |
| Never | 절대 하지 않는 일 |
| Selling your data, using it for ads, or sharing it without your permission. | 데이터 판매, 광고에 사용, 동의 없는 공유. |
| My Nuri | 마이 누리 |
| Diary | 다이어리 |
| Plan | 플랜 |
| You | 나 |
| Your world starts with your first meal. | 첫 식사를 추가하면 나의 세계가 시작돼요. |
| Your world today, empty so far. | 오늘의 세계, 아직 비어 있어요. |
| Add food | 음식 추가 |
| Scan a barcode | 바코드 스캔 |
| Nothing added yet today | 오늘은 아직 추가한 음식이 없어요 |
| Your daily guide appears after you set up your profile. | 프로필을 설정하면 하루 가이드가 표시돼요. |
| Cancel | 취소 |
| Food search is on its way | 음식 검색이 곧 제공돼요 |
| Search, barcode and label scanning arrive with the food database. | 검색, 바코드, 라벨 스캔은 음식 데이터베이스와 함께 제공돼요. |
| Nothing added yet | 아직 추가한 내용이 없어요 |
| Meals you add appear here, day by day. | 추가한 식사가 날짜별로 여기에 표시돼요. |
| Your plan is on its way | 플랜을 준비하고 있어요 |
| Suggestions for your week arrive once your profile is set up. | 프로필을 설정하면 한 주 제안이 도착해요. |
| Display | 화면 |
| Hide numbers | 숫자 숨기기 |
| Hides calories, nutrients, grams, minutes and ads everywhere in Nuri. | 누리 전체에서 칼로리, 영양소, 그램, 시간, 광고를 숨겨요. |
| Privacy | 개인정보 |
| Health data consent | 건강 데이터 동의 |
| Given | 동의함 |
| Anonymous usage stats | 익명 사용 통계 |
| On | 켜짐 |
| Off | 꺼짐 |
| About | 정보 |
| Version | 버전 |
| Start over | 처음부터 다시 시작 |
| Start over? | 처음부터 다시 시작할까요? |
| This clears your choices on this device and returns to the welcome screen. | 이 기기에서 선택한 내용을 지우고 시작 화면으로 돌아가요. |

- [ ] **Step 5: GREEN**: run `cd scripts && python3 -m unittest test_lint_copy -v`, then `python3 scripts/lint_copy.py ios/App/Localizable.xcstrings` (exit 0). The app test command must still pass.
- [ ] **Step 6: CI**: add this job to `ios.yml`:
```yaml
  copy-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cd scripts && python3 -m unittest test_lint_copy -v
      - run: python3 scripts/lint_copy.py ios/App/Localizable.xcstrings
```
- [ ] **Step 7: Commit**: `feat(app): English and Korean strings with copy lint`

---

### Task 9: Onboarding: Welcome, email, consent, data use

**Files:**
- Modify: `ios/App/NuriApp.swift`
- Create: `ios/App/RootView.swift`, `ios/App/Onboarding/OnboardingFlow.swift`, `WelcomeView.swift`, `EmailSignInView.swift`, `ConsentView.swift`, `DataUseView.swift`
- Create (temporary until Task 10): `ios/App/Tabs/MainTabView.swift` with `struct MainTabView: View { var body: some View { Text(verbatim: "Main") } }`
- Test: replace `ios/NuriUITests/LaunchUITests.swift` with `ios/NuriUITests/OnboardingUITests.swift`

**Interfaces:**
- Consumes: `AppState`, `UnavailableAuthService`, `EmailValidator`, and the DesignSystem components and tokens.
- Produces: `RootView` switches on `appState.stage`. Launch argument `-uiTestFreshState` gives a clean `UserDefaults` suite. Accessibility identifiers: `consent.adult`, `consent.healthData`, `consent.analytics`, `consent.continue`.

- [ ] **Step 1: Failing UI test** `OnboardingUITests.swift`:
```swift
import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testGuestOnboardingRequiresBothConsentsThenOpensMyNuri() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestFreshState"]
        app.launch()

        app.buttons["Use without an account"].tap()

        let proceed = app.buttons["consent.continue"]
        XCTAssertTrue(proceed.waitForExistence(timeout: 5))
        XCTAssertFalse(proceed.isEnabled)

        flip(app.switches["consent.adult"])
        XCTAssertFalse(proceed.isEnabled)
        flip(app.switches["consent.healthData"])
        XCTAssertTrue(proceed.isEnabled)

        let analytics = app.switches["consent.analytics"]
        XCTAssertEqual(analytics.value as? String, "0", "analytics must start off")

        proceed.tap()
        XCTAssertTrue(app.buttons["Add food"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAccountSignInExplainsItArrivesLater() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestFreshState"]
        app.launch()
        app.buttons["Continue with Apple"].tap()
        XCTAssertTrue(app.alerts["Account sign-in arrives in a later build"].waitForExistence(timeout: 5))
    }

    private func flip(_ toggle: XCUIElement) {
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    }
}
```
(`testGuest…` will reach "Add food" only after Task 10. Until then it fails at that last assertion, and that is the expected RED for this task. Make the rest pass now. Task 10 makes it fully green.)

- [ ] **Step 2: RED**: app test command.

- [ ] **Step 3: Implement**

`NuriApp.swift`:
```swift
import SwiftUI

@main
struct NuriApp: App {
    @State private var appState: AppState

    init() {
        let defaults: UserDefaults
        if ProcessInfo.processInfo.arguments.contains("-uiTestFreshState") {
            let suite = "nuri.uitest"
            UserDefaults().removePersistentDomain(forName: suite)
            defaults = UserDefaults(suiteName: suite) ?? .standard
        } else {
            defaults = .standard
        }
        _appState = State(initialValue: AppState(defaults: defaults))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .tint(.nuriTint)
        }
    }
}
```
(Add `import DesignSystem` wherever `.nuri*` tokens or components are used.)

`RootView.swift`:
```swift
import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.stage {
        case .complete: MainTabView()
        case .welcome, .consent: OnboardingFlow()
        }
    }
}
```

`Onboarding/OnboardingFlow.swift`:
```swift
import SwiftUI

enum OnboardingRoute: Hashable {
    case email, consent
}

struct OnboardingFlow: View {
    @Environment(AppState.self) private var appState
    @State private var path: [OnboardingRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(
                auth: UnavailableAuthService(),
                onEmail: { path.append(.email) },
                onWithoutAccount: {
                    appState.chooseGuest()
                    path.append(.consent)
                }
            )
            .navigationDestination(for: OnboardingRoute.self) { route in
                switch route {
                case .email:
                    EmailSignInView(onWithoutAccount: {
                        appState.chooseGuest()
                        path.append(.consent)
                    })
                case .consent:
                    ConsentView()
                }
            }
        }
        .onAppear { if appState.stage == .consent && path.isEmpty { path = [.consent] } }
    }
}
```

`Onboarding/WelcomeView.swift`:
```swift
import DesignSystem
import SwiftUI

struct WelcomeView: View {
    let auth: any AuthService
    var onEmail: () -> Void
    var onWithoutAccount: () -> Void
    @State private var showAccountsLater = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    WorldView(today: [.vegetables, .grains, .protein, .fruit], resting: [.legumesAndNuts],
                              accessibilityLabel: Text("An illustrated world of food groups"))
                        .frame(width: 196, height: 196)
                        .padding(.top, 40)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(verbatim: "누리").font(.system(size: 40)).foregroundStyle(Color.nuriTint)
                        Text(verbatim: "Nuri").font(.nuriTitle2).foregroundStyle(Color.nuriTint)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "Nuri"))
                    .accessibilityAddTraits(.isHeader)
                    Text("Food and movement, gently")
                        .font(.nuriTitle)
                        .multilineTextAlignment(.center)
                    Text("Log meals, watch your world grow, and get a plan that fits your week. Your data stays yours.")
                        .font(.nuriBody)
                        .foregroundStyle(Color.nuriInkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            }
            VStack(spacing: 10) {
                Button { request(.apple) } label: { Label("Continue with Apple", systemImage: "apple.logo") }
                    .buttonStyle(SolidButtonStyle(fill: .black, text: .white))
                Button { request(.google) } label: { Text("Continue with Google") }
                    .buttonStyle(SolidButtonStyle(fill: .white, text: Color(red: 0.12, green: 0.12, blue: 0.12), outline: Color(red: 0.455, green: 0.467, blue: 0.459)))
                Button(action: onEmail) { Label("Continue with email", systemImage: "envelope") }
                    .buttonStyle(SolidButtonStyle(fill: .nuriFillSecondary, text: .nuriInk))
                Button(action: onWithoutAccount) { Text("Use without an account") }
                    .buttonStyle(NuriTextButtonStyle())
                Text("For adults 18 and over. By continuing you agree to the Terms and Privacy Policy.")
                    .font(.nuriFootnote)
                    .foregroundStyle(Color.nuriInkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .background(Color.nuriGround.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .alert(Text("Account sign-in arrives in a later build"), isPresented: $showAccountsLater) {
            Button("Use without an account", action: onWithoutAccount)
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can use Nuri without an account now and add one later.")
        }
    }

    private func request(_ method: SignInMethod) {
        switch auth.availability(for: method) {
        case .comingLater: showAccountsLater = true
        case .available: break // accounts phase wires real sign-in here
        }
    }
}

/// Full-width 52 pt buttons for the sign-in choices (Apple black, Google white with outline).
private struct SolidButtonStyle: ButtonStyle {
    let fill: Color
    let text: Color
    var outline: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nuriHeadline)
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, minHeight: NuriMetrics.buttonHeight)
            .background(fill.opacity(configuration.isPressed ? 0.85 : 1),
                        in: RoundedRectangle(cornerRadius: NuriMetrics.radiusButton, style: .continuous))
            .overlay {
                if let outline {
                    RoundedRectangle(cornerRadius: NuriMetrics.radiusButton, style: .continuous).strokeBorder(outline, lineWidth: 1)
                }
            }
    }
}
```

`Onboarding/EmailSignInView.swift`:
```swift
import DesignSystem
import SwiftUI

struct EmailSignInView: View {
    var onWithoutAccount: () -> Void
    @State private var email = ""
    @State private var showLater = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("We will send a 6-digit code. No password to remember.")
                    .font(.nuriBody)
                    .foregroundStyle(Color.nuriInkSoft)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email").font(.nuriSubheadlineEmphasis)
                    TextField("you@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .frame(minHeight: NuriMetrics.buttonHeight)
                        .background(Color.nuriSurface, in: RoundedRectangle(cornerRadius: NuriMetrics.radiusControl, style: .continuous))
                }
                Button { showLater = true } label: { Text("Send code") }
                    .buttonStyle(NuriPrimaryButtonStyle())
                    .disabled(!EmailValidator.isPlausible(email))
                if showLater {
                    NoticeCard(title: Text("Account sign-in arrives in a later build"),
                               message: Text("Email sign-in arrives in a later build. You can use Nuri without an account now."),
                               actionTitle: Text("Use without an account"),
                               action: onWithoutAccount)
                }
            }
            .padding(.horizontal, NuriMetrics.screenMargin)
            .padding(.top, 8)
        }
        .background(Color.nuriGround.ignoresSafeArea())
        .navigationTitle(Text("Sign in with email"))
        .navigationBarTitleDisplayMode(.large)
    }
}
```

`Onboarding/ConsentView.swift`:
```swift
import DesignSystem
import SwiftUI

struct ConsentView: View {
    @Environment(AppState.self) private var appState
    @State private var adult = false
    @State private var healthData = false
    @State private var analytics = false

    private var ready: Bool { adult && healthData }

    var body: some View {
        List {
            Section {
                Toggle(isOn: $adult) { row("I am 18 or older", "Nuri is made for adults.") }
                    .accessibilityIdentifier("consent.adult")
                Toggle(isOn: $healthData) {
                    row("Store my food and activity data",
                        "Needed to run Nuri. This is health information, kept private and never sold or used for ads. Export or delete it anytime.")
                }
                .accessibilityIdentifier("consent.healthData")
                NavigationLink { DataUseView() } label: { Text("What we store and why") }
            } header: { Text("Required") }

            Section {
                Toggle(isOn: $analytics) { row("Share anonymous usage stats", "Helps improve Nuri. Never includes foods, notes or health data.") }
                    .accessibilityIdentifier("consent.analytics")
            } header: { Text("Optional") }

            Section {
                Text("Nuri gives general wellness estimates, not medical advice. Food energy, nutrients and exercise vary by person, preparation and device. For medical or nutrition guidance, talk to a qualified clinician.")
                    .font(.nuriFootnote)
                    .foregroundStyle(Color.nuriInkSoft)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("Before you start"))
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button {
                    try? appState.recordConsent(adult: adult, healthData: healthData, analytics: analytics)
                } label: { Text("Continue") }
                .buttonStyle(NuriPrimaryButtonStyle())
                .disabled(!ready)
                .accessibilityIdentifier("consent.continue")
                if !ready {
                    Text("Turn on the two required items to continue.")
                        .font(.nuriFootnote)
                        .foregroundStyle(Color.nuriInkSoft)
                }
            }
            .padding(.horizontal, NuriMetrics.screenMargin)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    private func row(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.nuriBodyEmphasis)
            Text(detail).font(.nuriFootnote).foregroundStyle(Color.nuriInkSoft)
        }
    }
}
```

`Onboarding/DataUseView.swift`:
```swift
import DesignSystem
import SwiftUI

struct DataUseView: View {
    var body: some View {
        List {
            item("Foods and meals you add", "To show your day, your world and your history.", symbol: "fork.knife")
            item("Activity you log or import", "To suggest a plan that fits your week.", symbol: "figure.walk")
            item("Your profile", "Age, height and weight, only to estimate your daily guide.", symbol: "person")
            item("Never", "Selling your data, using it for ads, or sharing it without your permission.", symbol: "hand.raised")
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("What we store and why"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func item(_ title: LocalizedStringKey, _ detail: LocalizedStringKey, symbol: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.nuriBodyEmphasis)
                Text(detail).font(.nuriFootnote).foregroundStyle(Color.nuriInkSoft)
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(Color.nuriTint)
        }
    }
}
```
- [ ] **Step 4: Run.** `testAccountSignInExplainsItArrivesLater` passes; `testGuest…` fails only at the final `Add food` assertion (expected until Task 10). The lint still passes. Every string used must exist in the catalog; add none that aren't in Task 8's table.
- [ ] **Step 5: Commit**: `feat(app): welcome, email sign-in placeholder and consent flow`

---

### Task 10: Main tabs, Hide numbers, You settings

**Files:**
- Replace: `ios/App/Tabs/MainTabView.swift`
- Create: `ios/App/Tabs/TodayView.swift`, `AddFoodSheet.swift`, `DiaryView.swift`, `PlanView.swift`, `YouView.swift`
- Test: extend `ios/NuriUITests/OnboardingUITests.swift`

**Interfaces:**
- Consumes: `AppState.hideNumbers`, `setHideNumbers(_:)`, `startOver()`, `consent`, and the DesignSystem.
- Produces: a 4-tab app. Identifiers: `today.guide`, `you.hideNumbers`.

- [ ] **Step 1: Add the failing UI test**
```swift
    @MainActor
    func testHideNumbersRemovesTheDailyGuideLine() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestFreshState"]
        app.launch()
        app.buttons["Use without an account"].tap()
        flip(app.switches["consent.adult"])
        flip(app.switches["consent.healthData"])
        app.buttons["consent.continue"].tap()

        XCTAssertTrue(app.staticTexts["today.guide"].waitForExistence(timeout: 5))
        app.tabBars.buttons["You"].tap()
        flip(app.switches["you.hideNumbers"])
        app.tabBars.buttons["My Nuri"].tap()
        XCTAssertFalse(app.staticTexts["today.guide"].exists)
    }
```
- [ ] **Step 2: RED.**
- [ ] **Step 3: Implement**

`MainTabView.swift`:
```swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView().tabItem { Label("My Nuri", systemImage: "globe.asia.australia") }
            DiaryView().tabItem { Label("Diary", systemImage: "book") }
            PlanView().tabItem { Label("Plan", systemImage: "figure.walk") }
            YouView().tabItem { Label("You", systemImage: "person.crop.circle") }
        }
    }
}
```

`TodayView.swift`:
```swift
import DesignSystem
import SwiftUI

struct TodayView: View {
    @Environment(AppState.self) private var appState
    @State private var addingFood = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.nuriSubheadlineEmphasis)
                        .foregroundStyle(Color.nuriInkSoft)
                    VStack(spacing: 12) {
                        WorldView(today: [], resting: [], accessibilityLabel: Text("Your world today, empty so far."))
                            .frame(width: 188, height: 188)
                        Text("Your world starts with your first meal.")
                            .font(.nuriBodyEmphasis)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    HStack(spacing: 10) {
                        Button { addingFood = true } label: { Label("Add food", systemImage: "plus") }
                            .buttonStyle(NuriPrimaryButtonStyle())
                        Button { addingFood = true } label: { Image(systemName: "barcode.viewfinder") }
                            .buttonStyle(NuriSecondaryButtonStyle())
                            .frame(width: NuriMetrics.buttonHeight)
                            .accessibilityLabel(Text("Scan a barcode"))
                    }
                    NuriCard {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nothing added yet today").font(.nuriHeadline)
                            if !appState.hideNumbers {
                                Text("Your daily guide appears after you set up your profile.")
                                    .font(.nuriSubheadline)
                                    .foregroundStyle(Color.nuriInkSoft)
                                    .accessibilityIdentifier("today.guide")
                            }
                        }
                        .padding(16)
                    }
                }
                .padding(.horizontal, NuriMetrics.screenMargin)
                .padding(.bottom, 24)
            }
            .background(Color.nuriGround.ignoresSafeArea())
            .navigationTitle(Text("My Nuri"))
            .sheet(isPresented: $addingFood) { AddFoodSheet() }
        }
    }
}
```

`AddFoodSheet.swift`:
```swift
import DesignSystem
import SwiftUI

struct AddFoodSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Food search is on its way", systemImage: "magnifyingglass")
            } description: {
                Text("Search, barcode and label scanning arrive with the food database.")
            }
            .background(Color.nuriGround.ignoresSafeArea())
            .navigationTitle(Text("Add food"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
```

`DiaryView.swift`:
```swift
import DesignSystem
import SwiftUI

struct DiaryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Nothing added yet", systemImage: "book")
            } description: {
                Text("Meals you add appear here, day by day.")
            }
            .background(Color.nuriGround.ignoresSafeArea())
            .navigationTitle(Text("Diary"))
        }
    }
}
```

`PlanView.swift`:
```swift
import DesignSystem
import SwiftUI

struct PlanView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Your plan is on its way", systemImage: "figure.walk")
            } description: {
                Text("Suggestions for your week arrive once your profile is set up.")
            }
            .background(Color.nuriGround.ignoresSafeArea())
            .navigationTitle(Text("Plan"))
        }
    }
}
```

`YouView.swift`:
```swift
import DesignSystem
import SwiftUI

struct YouView: View {
    @Environment(AppState.self) private var appState
    @State private var confirmingStartOver = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: Binding(get: { appState.hideNumbers }, set: { appState.setHideNumbers($0) })) {
                        Text("Hide numbers")
                    }
                    .accessibilityIdentifier("you.hideNumbers")
                } header: { Text("Display") } footer: {
                    Text("Hides calories, nutrients, grams, minutes and ads everywhere in Nuri.")
                }

                Section {
                    LabeledContent { Text(appState.consent == nil ? "Off" : "Given") } label: { Text("Health data consent") }
                    LabeledContent { Text(appState.consent?.analyticsOptIn == true ? "On" : "Off") } label: { Text("Anonymous usage stats") }
                    NavigationLink { DataUseView() } label: { Text("What we store and why") }
                } header: { Text("Privacy") }

                Section {
                    Text("Nuri gives general wellness estimates, not medical advice. Food energy, nutrients and exercise vary by person, preparation and device. For medical or nutrition guidance, talk to a qualified clinician.")
                        .font(.nuriFootnote)
                        .foregroundStyle(Color.nuriInkSoft)
                    LabeledContent { Text(verbatim: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") } label: { Text("Version") }
                } header: { Text("About") }

                Section {
                    Button(role: .destructive) { confirmingStartOver = true } label: { Text("Start over") }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("You"))
            .confirmationDialog(Text("Start over?"), isPresented: $confirmingStartOver, titleVisibility: .visible) {
                Button(role: .destructive) { appState.startOver() } label: { Text("Start over") }
                Button(role: .cancel) {} label: { Text("Cancel") }
            } message: {
                Text("This clears your choices on this device and returns to the welcome screen.")
            }
        }
    }
}
```
- [ ] **Step 4: GREEN.** The app test command passes all unit tests and all three UI tests. The lint passes. Then run the app on the simulator and save screenshots of Welcome, Before you start, My Nuri, and You, in light and dark, to `build/screenshots/` (git-ignored). Example: `xcrun simctl boot "iPhone 17"`, install the built `Nuri.app` from DerivedData, launch it with `xcrun simctl launch booted app.nuri.ios -uiTestFreshState`, then capture with `xcrun simctl io booted screenshot build/screenshots/welcome-light.png` and switch appearance with `xcrun simctl ui booted appearance dark`. List the screenshot paths in the report.
- [ ] **Step 5: Commit**: `feat(app): tabs, hide numbers and You settings`

---

### Task 11: README for the iOS app

**Files:** Create `ios/README.md`. It covers:
- How to open `ios/Nuri.xcodeproj` (Xcode 16+; developed on Xcode 27).
- The test commands from Global Constraints.
- Project layout (synchronized folders, so adding files needs no project edits).
- The design-system rules: tokens only, contrast tests, food-group colors reserved, Hide numbers contract, String Catalog plus `scripts/lint_copy.py`.
- The placeholder bundle id `app.nuri.ios`.
- What is placeholder in this phase: account sign-in, food search, plan.

- [ ] **Step 1:** Write the README, then run every command it lists once to confirm they work.
- [ ] **Step 2: Commit**: `docs(app): iOS README`

## Follow-up plans
1. **Local core:** SwiftData models, the onboarding profile (age, height, weight, sex, goal, readiness screen) wired to the engines, Today with the real ledger and world, Diary, the Plan screen backed by `MovementPlanner`, and food entry from the bundled offline database.
2. **Supabase:** schema, RLS, and accounts (Sign in with Apple, Google, email OTP), replacing `UnavailableAuthService`.
3. **Food data pipeline:** K-FIND, 유통바코드, USDA and Open Food Facts.

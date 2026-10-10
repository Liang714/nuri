# Nuri for iOS

SwiftUI app shell for Nuri: onboarding with consent, the four-tab layout, Hide numbers, and a You screen. iPhone only, portrait, iOS 17+, Swift 6, no third-party dependencies.

This is the app shell. Several features are placeholders; see [What is real and what is not yet](#what-is-real-and-what-is-not-yet).

## Open and run

1. Install Xcode 16 or later (developed on Xcode 27).
2. Open `ios/Nuri.xcodeproj` and run the `Nuri` scheme on an iPhone simulator.

The bundle id is the placeholder `app.nuri.ios` (tests: `app.nuri.ios.tests`, `app.nuri.ios.uitests`) and no development team is set yet. The simulator needs no signing; running on a device or shipping needs a real bundle id and team first.

Launch argument `-uiTestFreshState` runs the app against an empty, throwaway settings store, so onboarding starts from the welcome screen. The UI tests use it; you can add it under Edit Scheme > Run > Arguments to restart onboarding at will.

## Tests

Run from the repo root.

```sh
# Engines (pure Swift, runs on the Mac, no simulator)
swift test --package-path ios/Packages/NuriEngines

# Design system: palette, contrast, food groups, world layout, components
swift test --package-path ios/Packages/NuriDesignSystem

# App: unit tests and UI tests on the iPhone 17 simulator
xcodebuild test -project ios/Nuri.xcodeproj -scheme Nuri \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build/DerivedData -parallel-testing-enabled NO

# Copy lint, and its own unit tests
python3 scripts/lint_copy.py ios/App/Localizable.xcstrings
(cd scripts && python3 -m unittest test_lint_copy -v)
```

`-parallel-testing-enabled NO` keeps Xcode from cloning simulators; the clones stalled in local runs. If you have no iPhone 17 simulator, swap in any installed iPhone name. CI (`.github/workflows/ios.yml`, `engines.yml`) runs the same commands. The app job selects the newest installed non-beta Xcode and an iPhone simulator whose iOS version matches that Xcode's SDK (`scripts/pick_simulator.py`, newest older runtime as the fallback), and passes the simulator by id.

## Layout

```
ios/
  Nuri.xcodeproj
  App/                  app target
    NuriApp.swift         entry point, launch-argument handling
    AppState.swift        onboarding stage, consent record, Hide numbers (UserDefaults)
    ConsentCopy.swift     the consent-screen strings; only ConsentCopy.all is pinned to the consent version
    AuthService.swift     sign-in seam; UnavailableAuthService is the only implementation
    EmailValidator.swift
    Onboarding/           Welcome, email sign-in placeholder, Consent, DataUse
    Tabs/                 My Nuri, Diary, Plan, You, and the Add food sheet
    Localizable.xcstrings every user-facing string, English and Korean
  NuriTests/            unit tests (AppState, EmailValidator)
  NuriUITests/          onboarding and Hide numbers flows
  Packages/
    NuriEngines/          calculation engines (own README)
    NuriDesignSystem/     palette, type, metrics, components, the world view
```

`App`, `NuriTests` and `NuriUITests` are synchronized folders, so adding or moving a file inside them needs no project edit. Both packages are local package references; the app links the design system and the engines (the engines are not used by any screen yet).

## Design-system rules

- **Tokens only.** Colors come from `NuriPalette` through the `Color.nuri*` accessors (each is a light and dark pair), text from the `Font.nuri*` styles, sizes from `NuriMetrics`. Text styles are Dynamic Type styles in SF Pro Rounded; the only size not taken from a text style is the 누리 logotype, which is 40 pt at the default setting and scales with Dynamic Type through `@ScaledMetric`.
- **One documented exception.** The Apple and Google sign-in buttons follow the providers' brand colors (`BrandButtonColors` in `Onboarding/WelcomeView.swift`), light and dark.
- **Contrast is tested.** `PaletteTests` fails if any listed text pair drops below 4.5:1 or any non-text pair below 3:1, in both themes. Add a new token pair to those lists when you add a token.
- **Touch targets.** At least 44 pt everywhere (`NuriMetrics.minTouch`); primary buttons are 52 pt (`NuriMetrics.buttonHeight`).
- **Native first.** System `TabView` and `NavigationStack`, inset-grouped `List`, sheets with Cancel, `Toggle`, SF Symbols. Lists use `.scrollContentBackground(.hidden)` with `nuriGround` behind and `nuriSurface` rows, so they follow the palette in both themes.
- **Food-group colors are reserved.** `FoodGroup` fills and rings appear only in the world and its legend, never in buttons, charts or text.
- **Hide numbers.** When on, no calories, grams, nutrients, minutes or ads appear anywhere. The setting lives in `AppState.hideNumbers`, and the app root publishes it as the `nuriHideNumbers` environment value. `AdCard` and `NuriProgressBar` read it and gate themselves (the card renders nothing; the bar drops its spoken value), so a screen cannot leak an ad or amount by forgetting; screens still check it before showing their own numbers. The setting is named for what it does, never for a condition. Today's daily-guide line is the only gated element so far, covered by a UI test; new screens that show numbers must gate them and add a test.
- **Consent copy is versioned, with one source.** `ConsentCopy` (`App/ConsentCopy.swift`) holds every consent-screen string as a `LocalizedStringResource`, and `ConsentView` shows only those constants: `ConsentCopyTests` scans `ConsentView.swift` and fails on any string literal in it (any shape, any line) other than `.accessibilityIdentifier("...")` values, and on any `ConsentCopy` constant that is in neither list. Only `ConsentCopy.all` (what is stored and what people agree to) is pinned to the consent version: `AppState.consentVersion` is stored with each consent record, and the test hashes the English and Korean text of `all` and compares it with `AppState.consentCopyFingerprint`. Change any of those strings, in Swift or in the catalog, and the test fails and tells you to bump `consentVersion` (so people consent again) and update the fingerprint. A new string that says what is stored or agreed to goes in `all`. `ConsentCopy.chrome` (titles, section headers, the data-use link, button labels and hints) is localized the same way but is not pinned, so editing it does not change the consent.
- **Copy.** Every user-facing string lives in `ios/App/Localizable.xcstrings` with English and Korean values. Food actions say "Add", activity actions say "Log". Never moralize food or frame exercise as making up for eating. `scripts/lint_copy.py` scans the catalog for banned phrasing (English and Korean) and checks that every key has translated, non-empty `en` and `ko` values; CI runs it. The design-system package keeps its own small catalog (`Sources/DesignSystem/Resources/Localizable.xcstrings`) for strings inside its components; the lint does not scan it by default, so pass its path when you edit it (CI scans both):
  `python3 scripts/lint_copy.py ios/Packages/NuriDesignSystem/Sources/DesignSystem/Resources/Localizable.xcstrings`

## What is real and what is not yet

Working in this build:

- Welcome, then consent, then the app. Consent requires the adult confirmation and health-data consent; anonymous usage stats start off. The consent record (choices, time, consent-text version) is stored on the device, and a changed consent text sends people back to consent.
- The four tabs: My Nuri, Diary, Plan, You.
- Hide numbers toggle in You, saved on the device.
- You: consent status, what we store and why, the wellness disclaimer, version, and Start over, which clears onboarding, consent and Hide numbers on this device.

Placeholders or not built yet:

- **Account sign-in.** Continue with Apple, Continue with Google and email all end at "Account sign-in arrives in a later build". `UnavailableAuthService` reports every method as coming later. No account is created and no network call is made. People use Nuri without an account.
- **Email codes.** The email screen validates the address shape, but Send code sends nothing and shows the later-build notice.
- **Food search, barcode and label scanning.** The Add food sheet is an empty state; there is no food database in the app.
- **My Nuri and Diary.** The world is empty, the daily guide is a text placeholder, and nothing can be added, so the Diary stays empty. There is no persistent diary storage.
- **Plan.** An empty state. `MovementPlanner` exists in NuriEngines but is not connected.
- **Profile.** Age, height, weight, sex and goal are not collected yet, so no targets are computed.
- **Data export and delete.** Not built. Start over clears only the local onboarding choices.

Next up, in order: local core (storage, profile, ledger, diary, plan, bundled food data), then Supabase accounts and sign-in, then the food data pipeline.

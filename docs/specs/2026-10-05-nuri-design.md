# Nuri (누리) — Design Spec

**Status:** Approved 2026-10-05 · **Supersedes:** `docs/original-product-spec.md` where they conflict (the original spec still governs any detail not covered here, especially §4 safety wording and §10 security controls).

> Product renamed from "NutriBalance" to **Nuri**. Working App Store title: "Nuri: Food & Move" (trademark check on App Store, KIPRIS, and USPTO still pending; a variant may be needed because of the 누리호 rocket). Repo: `~/nuri`; Xcode target `Nuri`.

## Out of scope for v1
Android, Apple Watch/widgets, natural-language/voice logging, server-side photo inference, social features/leaderboards/streaks, coach sharing, languages beyond KO/EN, interstitial or tracking ads.

## Open items (resolve before public launch)
1. Trademark clearance for "Nuri" (App Store, KIPRIS, USPTO, EUIPO).
2. Confirm the license of each dataset at download time and record it in `docs/data-sources.md` (K-FIND and 유통바코드 are listed as "이용허락범위 제한 없음" on data.go.kr as of 2026-10-05).
3. Legal review of the privacy policy (GDPR, PIPA, US state health-data laws) and the wellness wording.
4. Sponsored/affiliate partners (e.g., Coupang Partners, Amazon Associates, iHerb); each checked against the banned-category list.

## Brand & UI direction
- **Story:** 누리 = "the world" / 누리다 = "to fully enjoy"; it sounds like "nourish." Food is something to enjoy, not a debt to pay off.
- **Signature home screen ("My Nuri"):** a soft living globe or garden. Color and life fill in through food *variety* and balance (vegetables, fiber, protein diversity), never through restriction or streaks. It never shrinks or withers; it simply rests on unlogged days.
- **Meal log moment:** the meal's color ripples across the world (respects Reduce Motion).
- **Palette:** earthy green, warm sand, sky blue; neutral progress colors (no red/green judgment); full dark mode.
- **Type:** rounded sans that pairs with Hangul (SF Pro Rounded + Apple SD Gothic Neo / Pretendard).
- **Exercise plan:** "Explore today," framed as a journey across your world, not a penalty.
- **Sponsored content:** fits naturally as "Discover the world's food," clearly labelled.
- Detailed visual design happens in a later design phase (Figma/prototype) before Phase 2 UI work.

## Context
Source spec: `~/Downloads/nutribalance_build_spec.md` (written for a team; Flutter + NestJS; ad-free; almost every paid feature left until after the MVP). We adapted it to these decisions:

| Decision | Choice |
|---|---|
| Priority | Solid foundation that is also built to earn money |
| Builder | Solo developer + Claude; an Xcode project ready for the App Store |
| Platform | iOS native first (SwiftUI, iOS 17+); Android later (the Supabase backend is ready for it) |
| Market | **Global equally**; Korean and English are first-class at launch |
| Accounts | **Email, Sign in with Apple, Google** (Supabase Auth) + guest mode (local only, upgrades to an account later) |
| Backend | **Supabase**: Auth, Postgres (food database + user data, row-level security), Edge Functions, Storage |
| Food data | **Real, official sources only, with provenance**: Korea MFDS K-FIND (~298k processed foods with manufacturer, ~19k dishes, raw foods) + MFDS distribution barcodes + USDA FDC + Open Food Facts |
| Core feature | Calorie-intake logging + **daily exercise plan** based on sex, age, BMI category, goal, and WHO guidelines, with safety caps |
| Ads | Privacy-safe sponsored/affiliate content only; no ad SDKs, no user data shared |
| Premium | Ad-free, photo logging, advanced insights, meal plan + grocery list, progressive weekly workout programs |
| Pricing | $4.99/mo, $29.99/yr, 7-day trial on annual (App Store sets local prices in each country) |
| Age | 18+ (App Store rating 17+) |

## Architecture

```
nuri/                                 (new git repo, ~/nuri)
  ios/
    Nuri.xcodeproj                    SwiftUI, Swift 6, iOS 17+
    App/                              entry, navigation, feature screens
    Packages/
      NutritionEngine/                BMR/TDEE (Mifflin-St Jeor), BMI + regional cutoffs, macros, recipe yield, serving conversion
      ActivityEngine/                 MET catalog (versioned), kcal estimate, DailyMovementPlan, equivalents, duplicate detection
      FoodKit/                        bundled offline SQLite (FTS5, Korean + English) + Supabase search + barcode + label OCR
      PersistenceKit/                 SwiftData local store, outbox sync to Supabase, export/import
      AuthKit/                        Supabase Auth (email OTP/password, Apple, Google), Keychain tokens, guest→account migration
      HealthKitBridge/                read-only HealthKit import
      MonetizationKit/                StoreKit 2 entitlements, paywall, sponsored feed
      DesignSystem/                   tokens, neutral progress components
  supabase/
    migrations/                       SQL schema, RLS policies, PGroonga/pg_trgm indexes for Korean/English search
    functions/                        Edge Functions: food search, barcode, report, sponsored, delete-account, verify-receipt
  data-pipeline/                      ETL: download → normalize → validate → load (TypeScript, run by GitHub Actions monthly)
  docs/                               spec, privacy, threat model, data sources/attribution, sponsored-content policy
  .github/workflows/                  iOS tests, migration tests, pipeline tests
```

### Food data pipeline (reliability = real sources + traceability + validation)
Sources, all licensed for commercial use. The license is recorded for every source in `docs/data-sources.md`, and an attribution screen in the app credits them.
1. **MFDS K-FIND / 식품영양성분DB** (data.go.kr 15127578, 15047698; license "이용허락범위 제한 없음"): processed foods with manufacturer (업체명) and product report number (품목제조보고번호), dishes, raw foods, per-100 g and per-serving values.
2. **MFDS distribution barcodes (유통바코드)** (data.go.kr 15063677): barcode → product report number → K-FIND nutrition.
3. **USDA FoodData Central** (public domain): global basic foods and US branded foods.
4. **Open Food Facts** (ODbL): global barcode fallback, labelled `community`.

Pipeline rules:
- One unified `foods` row per product, storing `source`, `source_id`, `source_updated_at`, `license`, and `pipeline_version`.
- Validation: an energy check (≈ 4/4/9 kcal per gram of carbs/protein/fat, with a tolerance band) and checks for missing required fields, negative values, and unit errors. Failures are flagged, not silently fixed.
- **Never** invent or AI-generate nutrition values. Government data takes priority over community data, and community data never overwrites verified data.
- Barcodes not found in any source: the user scans the package's nutrition label (on-device Vision OCR) → reviews and confirms → saved as `user_created`, optionally submitted for moderation.
- Monthly refresh. Each diary entry keeps its own nutrition snapshot, so history never changes.
- About 20k of the most common foods (Korean dishes and raw foods, USDA basics) are bundled for offline use. The full ~330k+ are searched via Supabase and cached locally.

### User data & sync
- SwiftData is the local source of truth; changes go into an outbox and sync to Supabase tables (schema follows spec §6.2). Each record carries `updated_at`, `deleted_at`, and `version`. Conflicts resolve by last write wins, with a conflict log.
- Row-level security: every row is restricted to `auth.uid()`.
- Guest mode works fully offline. Signing up uploads the local data.
- Account deletion in the app (Apple requires it): Edge Function revokes sessions, deletes the user's rows and storage, and emails a receipt; finished within 30 days.
- Free CSV/JSON export, generated locally.

### Daily exercise plan (core feature) — `ActivityEngine.DailyMovementPlan`
Inputs: sex (used by the energy formula), age, height, weight → BMI, goal, activity level, preferred activities, equipment, mobility limits, available minutes, a readiness screener (simplified PAR-Q: heart, joint, pregnancy, and similar questions).

Science:
- **Baseline:** WHO 2020 adult guidelines: 150–300 min/week moderate (or 75–150 vigorous) aerobic activity + muscle strengthening ≥ 2 days/week; balance work for 65+.
- **Energy:** Mifflin-St Jeor BMR × activity factor = TDEE; MET × kg × hours for activities (Compendium of Physical Activities, versioned).
- **BMI categories:** WHO cutoffs, or Asian-Pacific/KSSO cutoffs (23 overweight / 25 obese). The default follows region; the user can change it.
- **Gradual loss:** a 250–500 kcal/day deficit split between the food target and the activity plan (the user picks the split).

Output, e.g. "Today: 35–45 min brisk walk + 15 min bodyweight strength (est. 200–260 kcal)":
- Ranges plus a "why this plan" drawer that shows the formulas and sources.
- Mark done → logs the activity; never logged automatically.
- Neutral weekly progress toward the WHO minutes.

Safety caps:
- At most 90 min/day.
- Vigorous activity only if the user's activity level is moderate or higher.
- Low-impact options when BMI is in the obese range; progression of at most +10%/week.
- BMI < 18.5 → no weight-loss plan, health-maintenance plan only, plus a suggestion to see a clinician.
- Any "yes" on the readiness screener → recommend clinician clearance first; minutes-only light plan.
- Sensitive mode → minutes only, no kcal numbers.
- Wording is "recommended," never "must" or "burn off this meal."
- The per-meal "activity equivalents" from spec §5.6 stay opt-in and off by default.

## Monetization (reasonable, not predatory)
**Free:**
- Logging: search, barcode, label scan, manual.
- Diary, totals, recipes, favorites.
- Daily exercise plan, manual and HealthKit activity.
- 7/30-day trends, sync, export/delete.
- Shows sponsored content.

**Premium:**
- Ad-free.
- Photo meal logging (on-device Vision → candidates → user confirms).
- Advanced insights: 90-day/1-year trends, micronutrients, custom nutrient goals, weekly report, coach CSV.
- Meal plan + grocery list.
- Progressive weekly workout programs and a routine library.

**Sponsored content rules:**
- Placements: at most 1 labelled slot in search results, a "Discover" card below the diary, labelled affiliate links in the grocery list.
- Never pop-ups, never on the totals, never near the workout plan or equivalents, never during onboarding.
- Banned: diet pills, weight-loss supplements, detox, fat burners.
- The server selects content by placement + locale only; no user data is used.

**Billing:**
- StoreKit 2 `SubscriptionStoreView` (price, renewal period, trial end date). Receipts are verified by an Edge Function, so Premium follows the account.
- Soft paywall only when a Premium feature is tapped. Renewal reminder 7 days before the annual renewal.
- Data stays readable after Premium lapses. Export and deletion are always free.

## Safety, privacy, compliance
- Spec §4 and §10 apply in full: banned food words are linted by a CI script over the String Catalogs; disclaimer shown; low-target warning without blocking.
- No ad SDKs. Analytics are opt-in only (TelemetryDeck); crash data from MetricKit.
- GDPR + Korea PIPA: explicit consent screen for health data (separate consent for sensitive information is required under PIPA), privacy policy in KO/EN, data hosted in Supabase's region (Seoul `ap-northeast-2` available). Apple App Privacy labels: health data is linked to the user, not used for tracking.
- Permissions are requested only when needed (camera, HealthKit categories chosen individually).

## Build phases
- **0 — Foundation (1–2 wks):** repo, Xcode project, packages, CI, design tokens; NutritionEngine + ActivityEngine (incl. DailyMovementPlan) with exhaustive unit tests; Supabase project + migrations + RLS tests.
- **1 — Food data pipeline (2 wks):** K-FIND + barcode + USDA + OFF ETL, validation report, load into Supabase, build the bundled offline SQLite, search Edge Function (Korean + English).
- **2 — Local core (3–4 wks):** onboarding (disclaimer, 18+, goal, profile, readiness screener, wellbeing, target review); diary/dashboard with the separate ledger; search/barcode/label scan/manual; recipes, favorites; daily plan screen; settings; export.
- **3 — Accounts + sync (2 wks):** AuthKit (email, Apple, Google), guest migration, outbox sync, two-device test, delete account.
- **4 — Activity (2 wks):** manual MET logging, HealthKit import, duplicate detection, mark plan done, opt-in equivalents.
- **5 — Monetization (2–3 wks):** StoreKit 2 + receipt verification, paywall, sponsored feed, Premium features (insights, meal plan/grocery, workout programs, photo logging beta).
- **6 — Quality + launch (2–3 wks):** accessibility, dark mode, KO/EN localization pass, privacy labels/policies, TestFlight beta, App Review.
- **Later:** Android, more languages (JA, ZH, ES), natural-language/voice logging, Apple Watch/widgets.

## First step after approval
1. Write the design spec to `~/nuri/docs/specs/2026-10-05-nuri-design.md`, `git init`, commit.
2. Write a detailed Phase 0 + Phase 1 implementation plan, then start scaffolding.
3. You'll need to provide (I can't create accounts or enter keys): an Apple Developer account, a Supabase project, a data.go.kr API key and a 식품안전나라 OpenAPI key, a USDA FDC API key, and Google OAuth client IDs.

## Verification
- `xcodebuild test -scheme Nuri -destination 'platform=iOS Simulator,name=iPhone 17'`.
- Engine tests: BMR/TDEE by sex, BMI cutoffs (WHO vs Asian), plan caps (≤ 90 min, BMI < 18.5 has no loss plan, readiness flags, sensitive mode shows minutes only), MET math, recipe yield, time zones/DST, duplicate detection.
- Pipeline tests: sample K-FIND/barcode/USDA/OFF files → expected normalized rows; validation flags bad rows; spot-check 50 random Korean products against their printed labels.
- Supabase: RLS tests (user A can't read user B's data), delete-account test.
- UI tests: log food from recents in under 20 s; barcode → K-FIND match; plan shows ranges and the "why" drawer; export works for guests; sponsored content absent for Premium users.
- StoreKit `.storekit` config tests; TestFlight two-device sync test.

## Design direction (approved 2026-10-08)
Canvas: https://claude.ai/artifact/XG3oWYtrgt9AfdtH3vX9YE (private). Source boards and generator: `docs/design/visual-direction/`. Reviewed with impeccable (critique 23/40 → refined), design-auditor + web-design-guidelines (ship-ready direction with fixes, all applied).

- **Platform conventions:** native iOS first: large titles, grouped inset lists, sheets with Cancel, system tab bar (iOS 26 renders the floating Liquid Glass bar automatically), SF Symbols, Dynamic Type text styles (SF Pro Rounded, Apple SD Gothic Neo), 44 pt minimum targets, light + dark.
- **Tabs:** My Nuri, Diary, Plan, You. Adding food is a sheet ("Add food", meal picker, Cancel); food words use "Add", activity words use "Log".
- **Tokens:** mist ground #F2F4EF, white surfaces, ink #17211B, ink soft #4A5750, moss tint #3B6A4A, progress sky #4A82AB on track #E1E6E0, link sky #2F6690, sand #EADFC8; dark ramp ground #121714, surface #1C231E, ink #EEF2EC, ink soft #A9B5AC, tint #7FB58A (text on tint #121714), progress #7EB0D6, link #9CC3E2. Every text pair ≥ 4.5:1, non-text ≥ 3:1.
- **The world (signature):** six food groups with fixed fill + ring colors (vegetables #4F8A5B/#2F5A39, fruit #D07A9A/#8E4766, grains #E2B54E/#8A6A1E, protein #7E4127/#4A2414, legumes and nuts #8B7AC0/#5E4F94, dairy and alternatives #F6F3EA/#B5AE9C). Today's groups are filled; earlier this week rest as dashed outlines; nothing shrinks; no counts. VoiceOver reads a sentence. Group colors appear only in the world and its legend.
- **Energy copy:** "1,240 kcal so far" / "Daily guide about 2,000 kcal". Over the guide: same calm blue + "A guide, not a limit." No countdown, no red. Exercise energy is not shown on Home; activity shows minutes with "not added to your guide".
- **Hide numbers** (setting in You › Display; never named after a condition): hides energy, nutrients, grams, activity minutes, weekly totals and exercise energy everywhere, including search and Diary; food detail shows its food group; the plan shows days not minutes; **no ads at all**.
- **Ads (supersedes the earlier sponsored rules):** label first in the user's language, "Ad · [Partner]" / "광고 · [Partner]"; solid neutral outline; data source always shown; 44 pt "Why this ad" on every placement (sheet: not based on food log, Health data or settings; hide; fewer like this; remove ads with Premium; affiliate disclosure in EN/KO). Chosen by screen, season or search words only. Never next to totals, never right after a matching logged meal, never preselected. Banned: diet, weight-loss, detox, cleanse, supplement products and copy such as guilt-free, skinny, burn, before/after.
- **Sign in and first run:** Welcome (Continue with Apple, Continue with Google, Continue with email, Use without an account; 18+ and Terms/Privacy note) → email code sign-in (6-digit code, no password) → Before you start (required: 18+ confirmation and separate consent to store health data per PIPA; optional analytics, off by default; disclaimer; Continue disabled until required items are on). Production uses Apple's system Sign in with Apple button and Google's official button.
- **States designed:** undo after adding/logging, Done / Add another food, empty search, offline, Health permission off, loading, clinician notice with "Update my answers", largest-text layout rules.

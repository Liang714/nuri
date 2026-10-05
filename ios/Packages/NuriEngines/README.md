# NuriEngines

Pure Swift calculation engines for Nuri: energy targets, BMI, the daily ledger, recipe and serving math, MET-based activity estimates, and the daily movement plan. No UI, no network, no storage, no third-party dependencies.

Swift tools 6.0. Platforms: iOS 17, macOS 14 (macOS is declared only so `swift test` runs without a simulator).

## Targets

| Target | Depends on | Contents |
|---|---|---|
| `NuriDomain` | none | `BodyProfile` (with validation), `ActivityLevel`, `Goal`, `SexForEquation`, `CalendarDay`, `ActivityEnergySource` |
| `NutritionEngine` | `NuriDomain` | `BMI`, `EnergyTargetCalculator`, `GoalAdjustmentPolicy`, `LowTargetPolicy`, `DailyLedger`, `NutrientProfile`, `EnergyConsistency`, `RecipeCalculator`, `ServingConverter`, `roundTo` / `ceilTo` |
| `ActivityEngine` | `NuriDomain`, `NutritionEngine` | `METCatalog` (bundled JSON), `EnergyEstimator`, `ActivityEquivalents`, `DuplicateDetector`, `MovementPlanner` |

## Tests

```sh
swift test --package-path ios/Packages/NuriEngines
```

CI runs the same command (`.github/workflows/engines.yml`).

## Rules the engines follow

- **Enums, not strings.** Engines return no user-facing text. Outcomes are enums (`PlanNotice`, `PlanRationale`, `EquivalentsResult.SuppressionReason`, `ManualTargetAssessment`, `ProfileValidationError`, ...) and the app maps them to localized copy. The only string outputs are stable identifiers: activity ids, `EnergyTargetEstimate.method`, and duplicate fingerprints.
- **Deterministic.** No clock, locale or time-zone lookups. Time zone, first weekday, BMI standard and days remaining in the week are passed in.
- **Estimates are ranges.** Activity energy is returned as low / estimate / high.
- **Sensitive mode** removes kcal numbers from plan items and suppresses activity equivalents.
- **The ledger is separate lines**, never one net-calories number. Default exercise credit is `baseTargetOnly`.
- **Diary days** are `CalendarDay` values in the user's time zone, never UTC dates.
- **Users are adults.** `BodyProfile.validated()` rejects ages under 18.

## Evidence sources

| Used for | Source |
|---|---|
| Resting energy (BMR) | Mifflin MD, St Jeor ST, et al. Am J Clin Nutr. 1990;51(2):241-7 |
| Weekly activity targets, strength and balance sessions, 1 vigorous minute = 2 moderate | WHO Guidelines on physical activity and sedentary behaviour, 2020 |
| Weekly minutes for gradual loss | ACSM Position Stand on weight loss and prevention of weight regain, 2009 (Donnelly et al.) |
| BMI cutoffs, WHO standard | WHO, Obesity: preventing and managing the global epidemic, 2000 |
| BMI cutoffs, Asia-Pacific standard | WHO Western Pacific Region (2000) and Korean Society for the Study of Obesity cutoffs |
| MET values, vigorous = 6 MET or more | Compendium of Physical Activities: Ainsworth et al. 2011; Herrmann et al. 2024 (Adult Compendium) |
| Readiness screen | Simplified, adapted from PAR-Q+ |
| Energy consistency check | Atwater general factors, 4 / 4 / 9 kcal per g |

The +10% weekly progression cap is a conservative ramp heuristic, not a requirement of the guidelines above.

## Safety constants

| Constant | Value | Where it lives |
|---|---|---|
| Profile limits | age 18 to 120, height 100 to 250 cm, weight 30 to 350 kg | `NuriDomain/BodyProfile.swift` (`BodyProfile`) |
| Activity factors | 1.2, 1.375, 1.55, 1.725, 1.9 | `NuriDomain/BodyProfile.swift` (`ActivityLevel.factor`) |
| Loss adjustment | default -250, maximum -500 kcal/day | `NutritionEngine/EnergyTargets.swift` (`GoalAdjustmentPolicy`) |
| Gain adjustment | default +200, maximum +500 kcal/day | `NutritionEngine/EnergyTargets.swift` (`GoalAdjustmentPolicy`) |
| Minimum calculated target | 1500 kcal (male), 1200 kcal (female or no sex given); target rounded to 10 kcal | `NutritionEngine/EnergyTargets.swift` (`LowTargetPolicy`, `EnergyTargetCalculator`) |
| No sex given | no estimate returned; app offers manual target | `NutritionEngine/EnergyTargets.swift` (`EnergyTargetCalculator.estimate`) |
| Manual target | valid when 0 < kcal <= 10,000; below the minimum is `belowRecommendedMinimum` (non-blocking) | `NutritionEngine/EnergyTargets.swift` (`assessManualTarget`) |
| Underweight and loss | BMI < 18.5 in both standards; gradual-loss deduction not applied (`lossNotAppliedUnderweight`) | `NutritionEngine/BMI.swift`, `EnergyTargets.swift` |
| BMI cutoffs | WHO: 25 overweight, 30 obese. Asia-Pacific: 23 overweight, 25 obese | `NutritionEngine/BMI.swift` (`BMI.category`) |
| Asia-Pacific default regions | KR JP CN TW HK MO SG MY TH VN PH ID MN | `NutritionEngine/BMI.swift` (`BMIStandard.asianPacificRegions`) |
| Activity energy range | low 0.80x, high 1.25x of the estimate | `ActivityEngine/EnergyEstimator.swift` |
| Daily plan cap | 90 min/day, one budget shared by aerobic, strength and balance | `ActivityEngine/MovementPlanner.swift` (`dailyMaxMinutes`) |
| Minimum aerobic session | 10 min | `ActivityEngine/MovementPlanner.swift` (`minimumSessionMinutes`) |
| Weekly aerobic goal | 150 base, 300 upper (moderate-equivalent min) | `ActivityEngine/MovementPlanner.swift` (`weeklyAerobicGoalMinutes`) |
| Starting weekly minutes | 60 sedentary, 90 lightly active, 150 otherwise | `ActivityEngine/MovementPlanner.swift` (`startingWeeklyMinutes`) |
| Progression | with history: max(60, floor-to-5 of previous week x 1.10), capped at the goal | `ActivityEngine/MovementPlanner.swift` (`effectiveWeeklyMinutes`) |
| No catch-up spikes | today's aerobic <= ceil-to-5 of 2 x weekly target / 7 | `ActivityEngine/MovementPlanner.swift` (`plan`) |
| Vigorous threshold | an item is vigorous if and only if MET >= 6 | `ActivityEngine/MovementPlanner.swift` (`aerobicPrescription`) |
| Strength sessions | 2 per week; 3 for gradual gain and performance; 15 to 25 min each | `ActivityEngine/MovementPlanner.swift` (`strengthSessionsGoal`, `plan`) |
| Balance sessions | 3 per week at age 65 or older (tai chi, 10 to 15 min); none for seated-only | `ActivityEngine/MovementPlanner.swift` (`balanceSessionsGoal`, `plan`) |
| Readiness | any "yes" answer produces the clearance plan | `ActivityEngine/MovementPlan.swift` (`ReadinessScreen.needsClearance`) |
| Equivalents | opt-in; at most 5 options; session cap default 60 min; target must be 0 < kcal <= 5000 | `ActivityEngine/ActivityEquivalents.swift` |
| Duplicate activity | same activity type, different ids, overlap > 80% of the longer duration | `ActivityEngine/DuplicateDetector.swift` (`overlapThreshold`) |
| Atwater tolerance | stated energy flagged when off by more than max(20 kcal, 20%) | `NutritionEngine/Nutrients.swift` (`EnergyConsistency`) |

## Movement plan (`MovementPlanner.plan`)

- **Readiness.** Any "yes" returns the clearance plan: one light 10 to 20 min item (walking; stationary cycling for seated-only), no kcal numbers, notice `clinicianClearanceRecommended`.
- **Underweight (BMI < 18.5).** Always adds `underweightNoLossPlan` (the clinician-consultation signal), whatever the goal; the clearance plan is the exception, see Known limitations. Loss and performance goals are treated as maintain. Vigorous work is never allowed. Gradual gain keeps its goal.
- **Obese.** Only low-impact activities are eligible. Notice `lowImpactSelected` when a non-low-impact preference was dropped. Obese is decided by the user's BMI standard.
- **Vigorous work** requires all of: activity level at least moderately active, BMI not obese and not underweight, goal performance. A vigorous item uses half the minutes of its moderate-equivalent amount.
- **Intensity follows MET, not the catalog label.** Vigorous is used only when allowed and its MET is >= 6. Otherwise the first of moderate or light that is below 6 MET is used. An activity with no column under 6 MET is skipped for non-vigorous users, and the planner falls through to the next preference, then walking.
- **One daily budget** of `min(90, available minutes)`. Aerobic takes from it first. Strength needs at least 15 min left, balance at least 10. If time limits aerobic below 10 min, no aerobic item is added and `limitedByAvailableTime` is set.
- **Weekly aerobic goal.** Performance: 300. Gradual loss: the activity share of the deficit (share clamped to 0 to 0.5, deficit to 0 to 500 kcal) converted to minutes and bounded to 150 to 300. Everything else: 150.
- **Progression.** No history: start level, capped at the goal. With history: max(60, floor-to-5 of previous week x 1.10), capped at the goal. `progressingGradually` is set when the week is below the goal.
- **Strength** is skipped when the week's sessions are met, or when strength was done yesterday and there are more days left than sessions still owed. Strength is never vigorous.
- **Sensitive mode** sets `kcal` to nil on every item and omits the `metCompendium` rationale.

## Activity equivalents (`ActivityEquivalents.recommend`)

- Opt-in. Returns `.suppressed(reason)` when disabled, in sensitive mode, weight is missing, the target is invalid, or no activity fits the user's equipment and mobility.
- Aerobic and strength only. Moderate MET, falling back to light. Vigorous is never suggested.
- Ranking: preferred activities in the user's order, then shorter minimum duration, then id. Walking is always included when eligible.
- Minutes are shown as a range (80% to 125% of the estimate), rounded to 5 under 30 min and to 10 from 30 to 90. Above 90 the option is open-ended (`highIsOpenEnded`).
- `suggestSplitting` is set when the range is open-ended, the high end exceeds the session cap, or the low end exceeds the user's available minutes.

## Serving conversion

`ServingConverter.grams(quantity:unit:options:)` uses the first option matching the unit. For a serving the user picked, use `grams(quantity:option:)`. Volume and count units always need a food-specific gram weight; none is assumed.

## MET catalog

`ActivityEngine/Resources/met-catalog.json`, version `nuri-met-2026.1`, 11 activities.

**Open item before release:** the values in this catalog have not been verified against the Compendium of Physical Activities (pacompendium.com), and the entries carry no Compendium codes. Each value must be checked and its code recorded before any public release. Until then, treat the MET numbers as provisional.

## Known limitations

- `PlanNotice.cappedAtDailyMaximum` is currently unreachable: the spike cap keeps aerobic minutes at 90 or below.
- The clearance plan ignores available time and does not add the underweight notice.
- A seated-only user without a stationary bike gets an empty plan and no notice.
- `weekly.strengthSessions` uses the profile's goal before the underweight remap (an underweight performance user shows 3, not 2).
- Loss-goal weekly minutes use the primary activity's moderate MET (gross, resting energy not subtracted), even when light is prescribed.

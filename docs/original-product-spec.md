# Product Build Specification: NutriBalance
## Food logging, nutrition tracking, and exercise-equivalent planner

**Document purpose:** A complete implementation specification intended for Claude Code / Claude AI to build a production-ready MVP.  
**Product type:** Privacy-first mobile application with a companion web/admin backend.  
**Primary platforms:** iOS and Android.  
**Version:** MVP v1.0.

---

## 1. Product summary

Build **NutriBalance**, a food-and-activity tracker that helps people understand the relationship between what they eat and realistic activity choices. Users can log a meal, receive an estimated nutritional breakdown, see their daily calorie and macro progress, log or sync activity, and optionally view several equivalent activities for the meal, such as walking, running, cycling, swimming, or strength training.

The app must not shame users or imply they must “earn” food. The feature must be framed as **optional, educational, and goal-aware**: “Estimated activity equivalents” and “Ways to move,” not “You must burn this meal.” It must be hidden by default for users who select an eating-disorder-sensitive preference or opt out.

### Core promise

- Fast food logging with several input methods.
- Transparent and editable nutrition estimates.
- Personalized daily energy and macro targets.
- Exercise tracking that does not naively treat wearable calorie estimates as exact.
- Clear, optional activity-equivalent estimates that show ranges and assumptions.
- Privacy-first data ownership: export and deletion are always available.
- Reliable offline-first operation.

---

## 2. Product goals

### User goals

1. Log a typical meal in under 20 seconds after initial setup.
2. Understand calories, protein, carbohydrates, fat, fiber, and selected micronutrients.
3. Know progress toward a health goal without requiring restrictive behavior.
4. See useful exercise options based on preferred activity, available time, ability, and equipment.
5. Correct a food, serving size, category, or exercise estimate easily.
6. Keep using the app when offline, then synchronize safely later.
7. Export all personal data in common, readable formats.

### Business goals

1. Deliver a credible, privacy-first alternative to ad-funded calorie trackers.
2. Offer useful free core tracking; reserve non-essential convenience and advanced planning for premium.
3. Avoid misleading claims about medical diagnosis, exact calorie expenditure, or guaranteed weight loss.
4. Build a trusted food database and corrections pipeline over time.

### Non-goals for MVP

- Diagnosing or treating health conditions.
- Recommending compensatory exercise after eating.
- Live video exercise form analysis.
- Building a social network, public calorie feeds, or competitive streak mechanics.
- Building a proprietary foundation model.
- Supporting every country’s food database on day one.

---

## 3. User personas

### A. Casual tracker
Wants quick calorie awareness, simple meals, and a daily budget. Needs barcode/manual search and a clean dashboard.

### B. Fitness-focused user
Tracks protein and workouts. Wants wearable import, adjustable macro targets, exercise logging, trend charts, and editable estimates.

### C. Privacy-first user
Does not want bank-like data harvesting, advertising profiles, or mandatory cloud storage. Wants local-first storage, export, and opt-in backup.

### D. New health habit user
Needs calm explanations and flexible goals. Must not be overwhelmed by macros, gamification, or punitive alerts.

---

## 4. Safety and health requirements

### Mandatory wording and behavior

- Never call food “good,” “bad,” “guilty,” “cheat,” or “earned.”
- Never say a user must exercise to offset a meal.
- Use “estimated,” “approximate,” “may vary,” and a visible uncertainty range where relevant.
- Do not present calories burned as precise facts.
- Do not prescribe extreme calorie targets.
- Do not create exercise recommendations that exceed a user-configured limit or a conservative default.
- Do not send punitive notifications for missed logging, high intake, weight changes, or inactivity.
- Disable activity-equivalent surfaces when the user chooses `sensitive_mode = true`; make this accessible in onboarding and Settings > Wellbeing.
- If a user sets a medically concerning low target, show a non-diagnostic message recommending a registered dietitian or qualified clinician; do not block the user solely based on the number.

### Default safety configuration

```json
{
  "activity_equivalents_enabled": false,
  "sensitive_mode": false,
  "max_suggested_session_minutes": 60,
  "show_weight_loss_rate": false,
  "show_calorie_deficit": false,
  "notifications": {
    "meal_reminders": false,
    "movement_reminders": false,
    "weekly_summary": true
  }
}
```

### Medical disclaimer

Display during onboarding and in Settings: “NutriBalance provides general wellness estimates, not medical advice. Food energy, nutrient values, and exercise expenditure vary by person, preparation, device, and conditions. Consult a qualified clinician for medical or nutrition guidance.”

---

## 5. Feature set

## 5.1 Onboarding and profile

### Required onboarding screens

1. Welcome and wellness disclaimer.
2. Goal selection: maintain, gradual loss, gradual gain, improve nutrition, performance/support training, or “track without a goal.”
3. Profile: age range or age, optional sex field only where used by a selected energy equation, height, weight, units, usual activity level.
4. Dietary preferences/allergens: optional.
5. Activity preferences: walking, running, cycling, swimming, strength, yoga, home workout, other; available equipment; accessibility/mobility considerations.
6. Wellbeing controls: activity-equivalent toggle, sensitive mode, notification choice.
7. Target review: explain calculated estimate and allow manual override.
8. Account selection: local-only mode, sign in with email/passkey/Apple/Google, or continue later.

### Target calculation

Use Mifflin-St Jeor as the default BMR estimator, with user-visible formula explanation and a manual target override.

For male input:

\[
BMR = 10w + 6.25h - 5a + 5
\]

For female input:

\[
BMR = 10w + 6.25h - 5a - 161
\]

Where `w` is kilograms, `h` is centimeters, and `a` is years. For users who do not provide a sex value, offer manual target setup rather than making assumptions.

Estimate maintenance energy:

\[
TDEE = BMR \times activityFactor
\]

Activity factors: sedentary 1.2; lightly active 1.375; moderately active 1.55; very active 1.725; extra active 1.9. Explain that this is a starting estimate and adjust only from trends with explicit consent.

Goal adjustment defaults:
- Gradual loss: `-250 kcal/day` default, selectable up to a conservative app-defined maximum.
- Gradual gain: `+200 kcal/day` default.
- Maintain / track-only: `0 kcal/day`.

Never infer a calorie target from age/weight alone without showing it and allowing adjustment.

---

## 5.2 Home dashboard

### Dashboard components

- Today header with date and quick-add button.
- Calories eaten vs. personalized target; progress is neutral, not red/green moral judgment.
- Protein, carbohydrate, fat, fiber progress rings/bars; user can pin or hide metrics.
- Meal timeline: breakfast, lunch, dinner, snacks; editable labels.
- Activity section: logged activity, wearable-imported activity, and conservative adjustment status.
- Optional “Activity equivalents” card only if enabled and not sensitive mode.
- One-tap quick actions: scan barcode, photograph meal, search food, add saved meal, log activity.
- Sync/offline indicator.

### Daily math display

Show the ledger separately:

- Energy from food.
- Estimated activity energy (with source label: manual, wearable, imported).
- Daily target.
- Remaining planning amount.

Do not use “net calories” as the only figure; users must be able to disable exercise-adjusted targets.

---

## 5.3 Food logging

### Input methods

1. Text search: food name, brand, restaurant item, ingredient.
2. Barcode scan: packaged foods.
3. Recent and favorite foods.
4. Saved meals and recipes.
5. Manual food entry.
6. Photo-assisted estimate (optional beta; never represented as exact).
7. Voice/text natural-language parse: e.g., “two eggs, one slice whole-wheat toast, coffee with milk.”

### Food search requirements

- Display source and verification status: `verified`, `manufacturer`, `community`, `user-created`, `estimated from photo`.
- Rank exact brand/name matches above broad matches.
- Show serving unit and grams; let users switch servings without losing precision.
- Support at least grams, ounces, milliliters, cups, tablespoons, teaspoons, pieces, slices, and package serving.
- Show nutrition per selected serving and per 100 g when available.
- Provide “report incorrect item” flow.

### Food item detail fields

```ts
interface FoodItem {
  id: string;
  name: string;
  brand?: string;
  barcode?: string;
  source: 'verified' | 'manufacturer' | 'community' | 'user_created' | 'photo_estimate';
  verificationStatus: 'verified' | 'unverified' | 'pending_review';
  countryCode?: string;
  servingOptions: ServingOption[];
  nutrientsPer100g?: NutrientProfile;
  nutrientsPerServing?: NutrientProfile;
  ingredients?: string[];
  allergens?: string[];
  imageUrl?: string;
  updatedAt: string;
}

interface NutrientProfile {
  energyKcal: number;
  proteinG?: number;
  carbsG?: number;
  fatG?: number;
  fiberG?: number;
  sugarG?: number;
  sodiumMg?: number;
  saturatedFatG?: number;
  micronutrients?: Record<string, number>;
}
```

### Meal and recipe rules

- Recipes can include ingredients, quantities, cooking yield, servings, and notes.
- Recipes must calculate per-serving nutrition from ingredients.
- Users can duplicate a past meal, modify it, and save it as a favorite.
- Deleting food entries must be reversible for 30 seconds locally; use soft-delete sync semantics.

### Photo estimate flow

1. Ask user to photograph the plate or select an image.
2. On-device or server model identifies likely foods and portions.
3. Display candidate components, each with confidence and editable serving estimate.
4. Require a user review/confirmation before adding to diary.
5. Label the final record `photo_estimate` unless it is matched to a verified item.
6. Never estimate from a photo in the background without user confirmation.

MVP fallback: if no vision model is available, implement image attachment plus assisted manual logging; do not block the rest of the product on AI.

---

## 5.4 Nutrition tracking

### MVP nutrient support

Required: calories, protein, carbohydrates, fat, fiber, sugar, saturated fat, sodium.  
Optional in UI but supported in data model: potassium, calcium, iron, vitamin D, vitamin C, cholesterol, and other micronutrients.

### Target logic

- Users can choose goals for calories, protein, carbs, fat, fiber, sodium, and custom nutrients.
- Provide reasonable defaults, but never label nutrient targets as universally correct.
- Macronutrient grams must reconcile to energy only approximately because databases vary and fiber/alcohol/polyols may affect calculations.
- Show data source and last-update date where possible.

---

## 5.5 Exercise and activity logging

### Activity sources

1. Manual activity logging.
2. Apple Health / HealthKit import (iOS).
3. Health Connect import (Android).
4. Optional later integrations: Garmin, Fitbit, Strava, Polar.

### Manual activity fields

```ts
interface ActivityLog {
  id: string;
  userId: string;
  startAt: string;
  durationMinutes: number;
  activityTypeId: string;
  intensity: 'light' | 'moderate' | 'vigorous' | 'custom';
  distanceKm?: number;
  steps?: number;
  heartRateAvg?: number;
  energyKcal?: number;
  energySource: 'manual_met' | 'wearable' | 'health_platform' | 'custom';
  notes?: string;
  confidence: 'estimated' | 'device_estimate' | 'user_entered';
  createdAt: string;
  updatedAt: string;
}
```

### Energy expenditure calculation

Use standard MET estimates for manual activities. The basic estimate is:

\[
calories = MET \times weightKg \times durationHours
\]

Maintain a versioned MET activity catalog. Every activity estimate must show its MET source/version in a details drawer. Allow users to use a wearable/device value; do not combine duplicate records from imports and manual logs.

### Duplicate prevention

- Generate source-specific fingerprints for imported workouts.
- Flag activities overlapping by more than 80% in time with same type/duration as likely duplicates.
- Ask user once which source to prefer: wearable, health platform, or manual.
- Never silently double-count activity energy.

### Exercise-adjusted target modes

Settings options:

- `base_target_only`: never add workout energy to food target.
- `partial_credit`: add 25%, 50%, or user-selected percentage of estimated active exercise energy.
- `full_credit`: add 100% only with explicit user choice.
- `no_energy_math`: track activity separately.

Default: `base_target_only` for new users, because expenditure estimates can be inaccurate and baseline activity is often already included in TDEE.

---

## 5.6 Activity equivalents / “Ways to move”

### Product positioning

This is an **opt-in educational feature**, not a compensation tool. Place it behind a deliberate toggle during onboarding and in Settings. It must be disabled in sensitive mode.

### Trigger locations

- Food entry detail: “See approximate activity equivalents.”
- Daily summary: “Explore movement options.”
- Never show as an automatic warning after high-calorie meals.

### UI copy example

“An approximate 450 kcal amount could correspond to one of these activities. Your actual energy use varies with body size, pace, terrain, fitness, and device accuracy. Movement is optional; this is not a requirement to offset food.”

### Equivalent calculation

For a user-selected target energy `E` and activity MET `M`:

\[
minutes = \frac{E}{M \times weightKg} \times 60
\]

Return a range, not a single promise. Default uncertainty range: `-20%` to `+25%`, configurable per activity and confidence level. Round to practical intervals:

- Under 30 minutes: nearest 5 minutes.
- 30–90 minutes: nearest 10 minutes.
- More than 90 minutes: show `90+ minutes` and suggest splitting sessions or choosing another activity.

### Recommendation algorithm

Inputs:

```ts
interface MovementRecommendationInput {
  targetKcal: number;
  weightKg?: number;
  preferredActivities: string[];
  availableMinutes?: number;
  equipment: string[];
  mobilityPreferences: string[];
  sensitiveMode: boolean;
  enabled: boolean;
}
```

Rules:

1. If `enabled === false` or `sensitiveMode === true`, return no recommendations.
2. Select only activities compatible with user preference/equipment/accessibility profile.
3. Rank by preferred activity, fit to available time, and moderate intensity before vigorous intensity.
4. Cap displayed options at five.
5. Include walking or gentle alternatives where possible.
6. Do not recommend more than `max_suggested_session_minutes`; instead communicate a range and offer “split across the day.”
7. Never recommend activity as a mandatory response to eating.

### Example response

```json
{
  "targetKcal": 450,
  "disclaimer": "These are broad estimates, not a requirement to offset food.",
  "options": [
    {"activity": "Brisk walking", "minutesLow": 75, "minutesHigh": 105, "met": 4.3},
    {"activity": "Leisure cycling", "minutesLow": 45, "minutesHigh": 65, "met": 6.8},
    {"activity": "Easy swimming", "minutesLow": 40, "minutesHigh": 60, "met": 7.0}
  ]
}
```

---

## 5.7 Trends and insights

### MVP insights

- Weekly average calories and macros, not only daily swings.
- Meal-pattern trends: time of day, frequent foods, average protein/fiber.
- Activity duration trends and preferred activities.
- Optional body-weight trend, smoothed using a 7-day rolling average.
- Data-quality notices: “3 meals today were photo estimates; totals may be less precise.”

### Do not include in MVP

- Automatic diagnosis of eating behaviors.
- Aggressive nudges based on intake.
- “You failed” / “over budget” screens.
- Public leaderboard or calorie comparison.

---

## 5.8 Data import/export/deletion

### Import

MVP imports:

- CSV food diary import through a documented template.
- CSV body-weight import.
- CSV exercise import.
- Food-item import from a documented template.

Post-MVP: dedicated imports from popular trackers when legal/technically feasible.

### Export

One-click export from Settings > Data & Privacy:

- `foods.csv`
- `meal_entries.csv`
- `recipes.json`
- `activities.csv`
- `weights.csv`
- `profile.json`
- `full_backup.json` (versioned schema)

Exports must be generated locally when possible and work without a subscription.

### Deletion

- Delete individual records.
- Delete account and all server data from the app.
- Confirm destructive action using a typed confirmation or biometric check.
- Send a deletion receipt to the user’s verified email when applicable.
- Server deletion should be completed within 30 days; immediately revoke access tokens and mark records for deletion.

---

## 6. Product architecture

## 6.1 Recommended architecture

### Client

Use **Flutter** for shared iOS/Android UI with native platform channels for camera, HealthKit, Health Connect, barcode scanning, secure storage, and notifications. A React Native implementation is acceptable if the team has stronger expertise, but native modules must handle camera and health data reliably.

### Backend

- API: TypeScript with NestJS or Fastify.
- Database: PostgreSQL.
- Cache/queues: Redis + BullMQ or managed queue.
- Object storage: S3-compatible encrypted bucket for user-approved food photos only.
- Auth: OAuth 2.1 / OpenID Connect using a reputable managed identity provider, with passkeys supported.
- Search: PostgreSQL full-text/trigram search for MVP; add dedicated search engine only after need is proven.
- Analytics: privacy-respecting, opt-in product analytics; no ad SDKs.

### Local-first storage

- Local encrypted SQLite database (e.g., SQLCipher) as the source of immediate UI state.
- Background sync service uses an outbox pattern.
- Every mutable record has UUID, `createdAt`, `updatedAt`, `deletedAt`, `version`, and `syncStatus`.
- Conflict strategy: field-level last-write-wins for simple records, with conflict log; recipes and settings should use explicit conflict resolution UI if conflicting edits occur.

### High-level diagram

```text
Mobile app (Flutter)
  ├── Encrypted SQLite local store
  ├── Camera + barcode module
  ├── HealthKit / Health Connect adapters
  ├── Nutrition calculator
  ├── Offline outbox + sync engine
  └── API client
          |
          v
API gateway / Backend
  ├── Auth and account service
  ├── Food catalog/search service
  ├── Diary and recipe service
  ├── Activity and MET catalog service
  ├── Import/export service
  ├── Moderation/correction workflow
  └── Notification service
          |
          v
PostgreSQL / Redis / encrypted object storage
```

---

## 6.2 Data model

### Core tables

```sql
users (
  id uuid primary key,
  email text unique null,
  auth_provider text,
  created_at timestamptz not null,
  deleted_at timestamptz null
);

profiles (
  user_id uuid primary key references users(id),
  display_name text,
  birth_date date null,
  sex_for_equation text null,
  height_cm numeric null,
  weight_kg numeric null,
  activity_level text null,
  goal_type text not null,
  timezone text not null,
  unit_system text not null,
  sensitive_mode boolean not null default false,
  activity_equivalents_enabled boolean not null default false,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

nutrition_targets (
  id uuid primary key,
  user_id uuid references users(id),
  effective_from date not null,
  energy_kcal numeric null,
  protein_g numeric null,
  carbs_g numeric null,
  fat_g numeric null,
  fiber_g numeric null,
  sodium_mg numeric null,
  calculation_method text not null,
  settings jsonb not null,
  created_at timestamptz not null
);

foods (
  id uuid primary key,
  canonical_name text not null,
  brand text null,
  barcode text null,
  source text not null,
  verification_status text not null,
  country_code text null,
  nutrients_per_100g jsonb null,
  serving_options jsonb not null,
  allergens jsonb null,
  ingredients jsonb null,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

meal_entries (
  id uuid primary key,
  user_id uuid references users(id),
  food_id uuid null references foods(id),
  meal_type text not null,
  consumed_at timestamptz not null,
  quantity numeric not null,
  unit text not null,
  grams numeric null,
  nutrition_snapshot jsonb not null,
  source text not null,
  notes text null,
  photo_asset_id uuid null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz null,
  version integer not null default 1
);

recipes (
  id uuid primary key,
  user_id uuid references users(id),
  name text not null,
  servings numeric not null,
  ingredients jsonb not null,
  yield_grams numeric null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz null
);

activity_types (
  id uuid primary key,
  name text not null,
  category text not null,
  met_light numeric null,
  met_moderate numeric null,
  met_vigorous numeric null,
  equipment jsonb not null,
  accessibility_tags jsonb not null,
  source_reference text not null,
  catalog_version text not null
);

activity_logs (
  id uuid primary key,
  user_id uuid references users(id),
  activity_type_id uuid references activity_types(id),
  start_at timestamptz not null,
  duration_minutes numeric not null,
  intensity text not null,
  energy_kcal numeric null,
  energy_source text not null,
  external_source text null,
  external_id text null,
  source_fingerprint text null,
  raw_payload jsonb null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz null
);

weight_entries (
  id uuid primary key,
  user_id uuid references users(id),
  measured_at timestamptz not null,
  weight_kg numeric not null,
  source text not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz null
);
```

### Critical snapshot rule

Store a nutrition snapshot inside each `meal_entries` record. If the global food database changes later, historical diary totals must not silently change. Allow a user to consciously refresh an entry from newer data.

---

## 6.3 API design

Use REST or typed RPC. The following REST endpoints are minimum requirements.

### Authentication and profile

```text
POST   /v1/auth/register
POST   /v1/auth/login
POST   /v1/auth/refresh
POST   /v1/auth/logout
GET    /v1/me
PATCH  /v1/me/profile
GET    /v1/me/settings
PATCH  /v1/me/settings
DELETE /v1/me
```

### Food and meals

```text
GET    /v1/foods/search?q=&country=&limit=
GET    /v1/foods/{id}
GET    /v1/foods/barcode/{barcode}
POST   /v1/foods/user-created
POST   /v1/foods/{id}/report
GET    /v1/diary?date=YYYY-MM-DD
POST   /v1/diary/entries
PATCH  /v1/diary/entries/{id}
DELETE /v1/diary/entries/{id}
POST   /v1/recipes
GET    /v1/recipes
PATCH  /v1/recipes/{id}
DELETE /v1/recipes/{id}
```

### Activities and recommendations

```text
GET    /v1/activity-types
POST   /v1/activities
PATCH  /v1/activities/{id}
DELETE /v1/activities/{id}
POST   /v1/activity-equivalents
POST   /v1/integrations/health/sync
```

### Targets, trends, data portability

```text
GET    /v1/targets/current
POST   /v1/targets
GET    /v1/trends/weekly
POST   /v1/imports/csv
POST   /v1/exports
GET    /v1/exports/{jobId}
```

### Example: create food diary entry

```json
POST /v1/diary/entries
{
  "foodId": "food_uuid",
  "mealType": "lunch",
  "consumedAt": "2026-10-05T12:30:00+09:00",
  "quantity": 1.5,
  "unit": "serving",
  "grams": 225,
  "source": "search"
}
```

### Example: activity equivalents request

```json
POST /v1/activity-equivalents
{
  "targetKcal": 450,
  "availableMinutes": 45,
  "preferredActivities": ["walking", "cycling"],
  "enabled": true
}
```

Server must reject or return an empty set if the authenticated profile has sensitive mode enabled or activity equivalents disabled.

---

## 7. UX flows

## 7.1 Add food from search

1. User taps “Add food.”
2. User enters search text or scans barcode.
3. Results show name, brand, serving, calories, source/verification badge.
4. User selects item and adjusts serving with a prominent quantity control.
5. Nutrition preview updates instantly.
6. User chooses meal and time; default based on current time but editable.
7. User taps Add.
8. The entry appears immediately locally; sync occurs in background.

Acceptance criteria:
- Works with no network for recent items, saved meals, manually created foods, and cached foods.
- User can edit/delete immediately.
- A failure to sync never loses the local entry.

## 7.2 Add a meal by photo

1. User taps “Photo log.”
2. Explain photo estimate limitations before first use.
3. Capture/select photo.
4. Show detected candidates and portions; never auto-save.
5. User confirms or edits items.
6. Add as a normal meal entry with source metadata.

Acceptance criteria:
- Photo is not uploaded until consent is granted.
- The screen must work as assisted manual entry if recognition fails.
- User can delete photo after extraction without deleting the food entry.

## 7.3 View activity equivalents

1. User opens a meal or chooses “Explore movement options.”
2. If disabled, show a short explanation and toggle; no guilt-oriented copy.
3. If enabled, select target calories manually or use the meal total.
4. Show 3–5 suitable activities with ranges, intensity, and assumptions.
5. User may tap an option to prefill an activity plan, but the app must not automatically log it as completed.

Acceptance criteria:
- Recommendations are absent in sensitive mode.
- Output always includes uncertainty and a non-compensatory disclaimer.
- No recommendation exceeds configured maximum duration without offering split-session wording.

## 7.4 Export data

1. Settings > Data & Privacy > Export my data.
2. User selects CSV, JSON, or both.
3. Generate a signed download link or local share sheet.
4. Show included files and schema version.

Acceptance criteria:
- Available on free tier.
- Export completes for a 5-year diary within reasonable background job limits.
- No third-party analytics data is required for export.

---

## 8. Screens to build

1. Splash / offline recovery.
2. Onboarding: disclaimer, goal, profile, preferences, wellbeing controls, target review.
3. Auth and local-only account choice.
4. Home dashboard.
5. Diary day view.
6. Add food hub.
7. Search results.
8. Food detail and serving picker.
9. Barcode scanner.
10. Manual food editor.
11. Photo-log review.
12. Recipe builder.
13. Saved meals/favorites.
14. Add activity.
15. Activity detail/history.
16. Activity equivalents.
17. Nutrition details.
18. Trends.
19. Weight log.
20. Settings: targets, integrations, notifications, wellbeing, data/privacy, account.
21. Export/import center.
22. Help and report-data-error flow.
23. Admin web console: food records, reports, corrections, user deletion/export job status, MET catalog version management.

---

## 9. Design system requirements

- Clean, calm, high-contrast interface; avoid red/green “pass/fail” visual language.
- Use accessible font sizes and Dynamic Type / Android font scaling.
- Minimum 44x44 pt touch targets on iOS equivalent and 48dp on Android.
- WCAG 2.2 AA contrast target.
- Support light/dark mode.
- Use charts that include text summary for screen-reader users.
- Avoid crowded numeric dashboards; allow users to choose pinned metrics.
- Localize strings from day one; do not hard-code units, date formats, or calorie wording.

---

## 10. Privacy and security

### Principles

- No advertising SDKs.
- No sale or sharing of personal health/nutrition data for advertising.
- Collect only data needed to provide the chosen features.
- Food photos remain optional and should be processed on-device where feasible.
- Local-only mode must be fully functional for manual logging, saved meals, calculations, and export.

### Security controls

- TLS 1.3 in transit.
- Encryption at rest for databases and object storage.
- Secure device storage for tokens and encryption keys.
- Short-lived access tokens with refresh token rotation.
- Signed upload URLs, content-type validation, malware scanning for uploads.
- Strict authorization checks on every resource by authenticated user ID.
- Rate limits on login, barcode lookup, photo endpoints, and export generation.
- Audit logs for admin actions, export requests, deletion requests, and food database changes.
- Never store third-party health platform credentials when platform-native authorization is available.

### Permission rules

- Request camera permission only when barcode/photo feature is opened.
- Request HealthKit/Health Connect permissions only after explaining the exact categories requested.
- Let users choose read-only categories separately: workouts, active energy, steps, body weight.
- Never request location unless a future route-tracking feature is explicitly opened.

---

## 11. Food data strategy

### MVP data sources

Use legally permitted food-data sources appropriate to launch countries, manufacturer-provided nutrition data, and user-created foods. Track provenance at record level.

### Quality rules

- `verified`: audited/official/manufacturer source with required nutrition fields.
- `community`: visible warning and editable by user; not used as a silent authority.
- Barcode collision handling: country and brand context; never overwrite a verified record with community content.
- Allow correction reports with reason, screenshot/photo evidence optional, and a moderation queue.
- Version nutrition records; retain historical snapshots in diaries.

### Avoid

- Scraping copyrighted food databases without permission.
- Claiming food values are “exact.”
- Publishing unreviewed community foods as verified.

---

## 12. Monetization model

### Free tier (must remain useful)

- Manual/search/barcode food logging.
- Daily diary and nutrition totals.
- Manual activity logging.
- Basic activity equivalents if explicitly enabled.
- Local storage and full data export.
- Basic trends.
- No ads, no sale of personal data.

### Premium tier (optional)

- Photo-assisted logging quota or unlimited use, depending on model costs.
- Advanced trend analysis and custom nutrient goals.
- Meal planning and grocery list.
- Unlimited cloud sync / family sharing only with explicit consent.
- Advanced integrations and coach export.
- Expanded recipe and food library features.

### Billing requirements

- Clearly show price, currency, renewal cadence, and trial end date before purchase.
- In-app cancellation instructions.
- Renewal reminder notification/email at least 7 days before annual renewal where permitted.
- Do not remove access to locally stored historical data when subscription ends.
- Never charge for export or account deletion.

---

## 13. MVP delivery plan

## Phase 0: Product foundation (1–2 weeks)

- Confirm primary launch country, food-data source licensing, legal/privacy copy, and target audience.
- Define design system, database schema, calculation library, and event taxonomy.
- Build clickable prototype and usability-test onboarding, diary, and activity-equivalents safety copy with 5–8 target users.

Deliverables:
- PRD approved.
- Figma low/high fidelity core screens.
- Architecture decision record.
- Privacy threat model.

## Phase 1: Local-first core (3–5 weeks)

- Flutter shell, navigation, theme, localization infrastructure.
- Encrypted local database and outbox sync abstraction.
- Onboarding, profile, manual calorie/macronutrient target configuration.
- Manual foods, meal diary, saved meals, favorites, recipes.
- Daily dashboard and basic nutrient calculations.
- CSV/JSON export.

Definition of done:
- A user can finish onboarding, create/edit/delete food entries offline, view totals, and export data.

## Phase 2: Food discovery and backend (3–5 weeks)

- Auth/local-only mode.
- Backend APIs, PostgreSQL migrations, food search, cached catalog.
- Barcode scan and lookup.
- Food source/verification indicators and correction reports.
- Cloud sync and conflict handling.

Definition of done:
- Food entries synchronize across two devices without duplicate records; all data remains usable offline.

## Phase 3: Activities and safety-aware equivalents (2–4 weeks)

- Manual activity logging.
- Versioned MET catalog.
- Exercise energy estimate engine.
- Activity equivalents screen, opt-in settings, sensitive mode gating.
- Wearable import adapters: HealthKit and Health Connect.
- Duplicate activity detection.

Definition of done:
- Equivalent estimates are ranges, have safety disclaimer, respect user settings, and never auto-log activity.

## Phase 4: Quality and beta (2–4 weeks)

- Trend charts, weight log, accessibility work, performance optimization.
- Analytics consent flow, crash monitoring, security testing.
- App Store / Play Store listing assets and privacy labels.
- Closed beta with 50–200 testers.

Definition of done:
- Core flows meet performance and reliability metrics; critical bugs resolved; export/delete verified.

## Phase 5: Post-MVP roadmap

- Photo-assisted logging, beginning as an editable beta.
- Natural-language food entry.
- More food-market coverage and regional localization.
- Meal planning and grocery lists.
- Coach sharing with granular consent.
- Adaptive energy guidance based on trend data only with transparent explanation and opt-in.

---

## 14. Testing plan

### Unit tests

- BMR/TDEE calculator inputs, units, rounding, manual override.
- Macro/nutrient arithmetic.
- Recipe yield and per-serving calculations.
- MET calorie estimate math.
- Equivalent time ranges and caps.
- Timezone/date boundary logic.
- Duplicate workout detection.
- CSV import validation and export schema.

### Integration tests

- Authentication and account deletion.
- Offline create/update/delete then reconnect sync.
- Conflict cases from two devices.
- Barcode lookup cache behavior.
- HealthKit/Health Connect import mapping and duplicate suppression.
- Photo consent and asset deletion.

### UI tests

- Add food in under 20 seconds from recent/favorite list.
- Serving adjustment is accessible via screen reader.
- Activity equivalents do not appear when disabled or sensitive mode is enabled.
- Export flow works for free account/local-only account.
- Dark mode and font scaling do not truncate key numbers.

### Test data

- Foods with per-100 g and per-serving values.
- Branded foods with multiple serving units.
- Recipes with fractional servings.
- Activities across intensity levels and weights.
- Time zones around midnight and daylight-saving changes.
- Corrupted/missing nutrition fields.

---

## 15. Acceptance criteria

### Core diary

- Users can create, edit, duplicate, and delete meal entries.
- Daily totals update locally within 200 ms for standard diary sizes.
- Historical entry totals remain unchanged when catalog records are updated.
- Diary works without internet for local and cached content.

### Nutrition integrity

- Every food entry displays source and verification status when not user-created.
- A user can correct quantity and category without re-adding the food.
- Calculations use one central library shared by client and server or test vectors that ensure equivalence.

### Activity integrity

- Manual exercise uses a documented MET value and records the catalog version.
- Imported and manual activities are not double-counted.
- Device-reported calorie values are clearly labeled as estimates.

### Safety

- Activity equivalents are disabled by default.
- Sensitive mode suppresses activity equivalents everywhere, including deep links and API responses.
- No notification or screen frames food as something that must be compensated for.

### Data rights

- Users can export food, diary, activity, recipes, weight, and profile data without paying.
- Users can initiate deletion from the app.
- Local-only user can use core diary and export without account creation.

### Performance

- Cold start target: under 2.5 seconds on representative mid-range devices.
- Common dashboard interaction target: under 100 ms local response.
- Barcode screen initial open target: under 1 second after permission grant on supported devices.
- Background sync must not materially block UI.

---

## 16. Analytics and metrics

Only collect analytics after explicit consent. Use anonymous/pseudonymous event IDs and avoid logging food names, meal notes, images, precise health metrics, or identifiers in analytics.

### Product events

```text
onboarding_completed
food_added (method only: search/barcode/manual/photo/recent)
food_corrected
meal_saved
activity_logged (source/type category only)
activity_equivalents_viewed
activity_equivalents_disabled
export_requested
account_deletion_requested
sync_conflict_detected
subscription_started
subscription_cancelled
```

### Success metrics

- Activation: user logs at least 3 meals in first 3 days.
- Week-4 retention.
- Median time to log food.
- Food-search zero-result rate.
- Food-correction rate by source.
- Sync error rate.
- Crash-free sessions.
- Percentage of users who explicitly enable activity equivalents; do not optimize for this metric at expense of wellbeing.

---

## 17. Implementation notes for Claude

### Code quality requirements

- Use strict TypeScript/Dart typing; avoid `any`/dynamic except at explicit API boundaries.
- Separate domain logic from UI and transport code.
- Write tests alongside all calculation logic.
- Create feature flags for photo logging, external integrations, premium gates, and activity equivalents.
- Use environment variables/secrets manager; never commit keys.
- Include a README with local setup, environment variables, migration commands, test commands, and architecture overview.
- Include OpenAPI documentation or generated typed client contracts.
- Seed development database with representative verified foods and activity types.
- Add structured error handling and user-safe error messages.

### Suggested repository structure

```text
nutribalance/
  apps/
    mobile/                 # Flutter mobile app
    api/                    # NestJS/Fastify backend
    admin/                  # Admin web console
  packages/
    domain/                 # Shared entities, calculation test vectors
    api-contracts/          # OpenAPI/types
    nutrition-engine/       # calorie/macro/recipe logic
    activity-engine/        # MET/equivalent logic
    design-tokens/
  infra/
    docker/
    migrations/
    terraform-or-iac/
  docs/
    product-spec.md
    api.md
    privacy.md
    threat-model.md
```

### First build order

1. Scaffold monorepo, CI, linting, formatting, unit test harness.
2. Implement shared nutrition/activity calculation packages with exhaustive tests.
3. Implement mobile local database and offline diary UI.
4. Implement backend/auth/sync.
5. Implement food search/barcode.
6. Implement activity logging and optional equivalents with safety gating.
7. Implement export/delete and privacy controls.
8. Add health integrations, trends, then photo/NLP features behind flags.

---

## 18. Open product decisions

Resolve before public launch:

1. Launch geography and permitted food-data provider(s).
2. Exact premium price and photo-inference unit economics.
3. Whether weight tracking appears in onboarding or later as optional.
4. Whether server-side photo inference is allowed; if yes, retention, consent, and deletion policy.
5. Which external health integrations ship in MVP beyond HealthKit/Health Connect.
6. Legal review of wellness language, age-gating, privacy policy, and health-data regulations in launch markets.

---

## 19. Final MVP checklist

- [ ] Local-only mode works without account creation.
- [ ] Manual logging, search, barcode, recipes, favorites, and diary are complete.
- [ ] Nutrition math and historical snapshots are tested.
- [ ] Manual activities and health-platform imports do not double-count.
- [ ] Activity equivalents are opt-in, range-based, optional, and suppressed in sensitive mode.
- [ ] Export and deletion are free and discoverable.
- [ ] No ad SDK and no sale/sharing of health data for advertising.
- [ ] Accessibility, dark mode, offline behavior, and error states are tested.
- [ ] Food-data sources have documented provenance and verification badges.
- [ ] Privacy policy, disclaimer, support flow, app-store privacy labels, and incident-response plan are ready.

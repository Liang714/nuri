# App shell — decisions made during autonomous build (2026-10-08 → 10-10)

Every ruling the controller made on the plan's behalf, in order, with what it costs if wrong. Review and push back on any.

- Ruling: branch in main checkout (same as engines plan) — cost if wrong: none.
- Ruling: all implementers on sonnet (not haiku) — an earlier haiku implementer fabricated test output; reliability over cost — cost: higher token spend.
- Ruling: batches — T1 alone; T2–T5 (one package, complete code); T6 alone (project file); T7–T8; T9–T10 (T9's UI test only goes fully green in T10); T11 alone.
- | T8→T9,T10 | string keys table vs view literals | consistent; risk: YouView `Text(cond ? "Off" : "Given")` may resolve to String overload (unlocalized) — Ruling: use explicit LocalizedStringKey in implementation |
- Ruling: accept implementer's README + PlanNotice doc edits outside the file list — they correct now-false docs — cost if wrong: none (docs only).
- Ruling: NoticeCard combines title+message only, card uses .contain, button stays its own element — VoiceOver must reach controls — cost: none.
- Ruling: add WorldPalette.halo ThemedColor(light 0xFFFFFF, dark 0x22313A = globe) and use it — every color from palette tokens — cost: none.
- Ruling: fold two constraint-level minors into the same round: NuriTextButtonStyle gets minWidth 44 (44pt constraint); package catalog gets an explicit "en" value (copy rule) — cheap, same files — cost: none.
- Ruling: accept `nonisolated` on NuriProgressBar.fraction (minimal Swift 6 fix).
- Ruling: fold CI hardening into Task 8 (which already edits ios.yml): pick simulator by UDID from `simctl list -j` with fail-fast, add timeout-minutes and concurrency cancel-in-progress — cheap, same file — cost: none.
- Ruling: drop 성인 everywhere; "Nuri is made for adults." KO → "누리는 만 18세 이상을 위한 앱이에요." Product question (19+ for Korea?) surfaced to the user — cost if wrong: copy only.
- Ruling: welcome blurb key becomes "Add meals, watch your world grow, and get a plan that fits your week. Your data stays yours." (KO 식사를 추가하고…); add lint rule for "log (your) meal(s)/food(s)".
- Ruling: expand lint (EN cheat/burn/work-off variants; KO with \s*: 보상 운동, 살 빼, 다이어트 실패, 나쁜/좋은 음식, 정크 푸드, 칼로리를 태, 운동으로 만회) + tests; dedupe findings; add __pycache__/ to .gitignore.
- Ruling: remove the unverifiable Terms/Privacy agreement sentence until legal documents exist — footer becomes "For adults 18 and over." (KO "만 18세 이상을 위한 앱이에요.") — cost: legal pages + links must be added before launch (spec open item).
- Ruling: ad wording precision — consent: "kept private and never sold or used to target ads"; data use Never: "Selling your data, using it to target ads, or sharing it without your permission." (KO 맞춤 광고).
- Ruling: Korean wording fixes: 시간→운동 시간 in Hide numbers footer; 다음 버전→이후 버전; tab 마이 누리→내 누리; 계획→플랜 consistently; "플랜이 곧 준비돼요"; "식품군으로 그려진 세계"; disclaimer KO rewritten (누리가 제공하는 정보는…, 의료 전문가).
- Ruling: AppState hardening folded in: chooseGuest only from .welcome; complete stage trusted only when consent.consentVersion == current (forces re-consent on text change); ISO-8601 dates in the record — tests added.
- Ruling: Apple button = black fill/white text in light, white fill/black text in dark (Apple "white" style); provider colors live in one documented BrandButtonColors exception — Apple/Google brand rules — cost: none.
- Ruling: Welcome buttons move inside the ScrollView (stack stays at bottom via spacer/min-height) with labels allowed to wrap — AX sizes must work.
- Ruling: Consent/DataUse/You Lists: .scrollContentBackground(.hidden), .background(Color.nuriGround), .listRowBackground(Color.nuriSurface).
- Ruling: email field gets a 1pt Color.nuriAdOutline stroke (3.15/4.8:1) and a proper label (TextField(text:prompt:label:)).
- Ruling (folded minors, same files): add NuriPalette.destructive (light 0xB3261E, dark 0xFF8A80; contrast-tested) for Start over; OnboardingFlow initializes path from stage and guards double push; UI hide-numbers test asserts Add food visible and toggle value "1"; CI + README use -parallel-testing-enabled NO.
- Ruling F1: all secondary text on palette backgrounds uses nuriInkSoft (section headers/footers, LabeledContent values, ContentUnavailableView descriptions) via design-system helpers; add performAccessibilityAudit to UI tests (contrast + more), triaging any exception explicitly.
- Ruling F2: CI selects the newest installed Xcode, prints versions, picks a simulator whose runtime matches the SDK; engines.yml gets timeout/concurrency; CI lints the design-system catalog too. Cannot verify until a remote exists (user must `gh auth login`).
- Ruling F3 (gate, not now): before local core stores any data — complete PIPA notice (all items incl. sex/activity/goal/readiness, retention, right to refuse), deliver export/delete, consent withdrawal, locale in record. Recorded as Task 0 gate of the next plan.
- Ruling F4: EnvironmentValues.nuriHideNumbers in DesignSystem, set at the root from AppState; AdCard renders nothing and NuriProgressBar drops its numeric accessibility value when on. EN/KO no-numbers UI sweep becomes first local-core task.
- Ruling (folded minors): -uiTestFreshState only in DEBUG; NoticeCard action minWidth 44; lint adds "burn N kcal" and before/after, fixes "works off-device" false positive, checks every key has translated en+ko; consent-copy hash test pinned to consentVersion; UI tests pin -AppleLanguages (en); logotype @ScaledMetric + localized a11y label; barcode button 52pt; primary button wraps centered; Korean polish (자라나는 모습을 보고, 내 데이터는 내 것이에요, 이번 주 제안을 받을 수 있어요).
- Final: parked — consent fingerprint misses English edits made in Swift literals (README overclaims) — Ruling: real and load-bearing for the next phase → Task 1 of local-core plan: one shared ConsentCopy key list used by ConsentView and the test (+ fail if a key is missing/stale), fix README line — cost if wrong: a consent copy change could ship without re-consent until fixed.
- Final: parked — accessibility audit false positive (contrast 7.35:1 measured) on iPhone 18 Pro Max for the consent footnote — Ruling: narrow .contrast filter with measurement comment in local-core Task 1; CI picker avoids Pro Max — cost: none.

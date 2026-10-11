import DesignSystem
import NuriDomain
import NutritionEngine
import Persistence
import SwiftUI

/// What the own-number field of the daily guide step holds. Only digits count (at most five), and the engine decides which
/// numbers it can use, so the field and the calculation never disagree.
enum ManualTargetInput: Equatable {
    /// No digits: no own number.
    case empty
    case valid(Double)
    /// Digits the engine cannot use: 0, or more than `maximumKcal`.
    case invalid

    /// The largest own number the engine accepts (see `EnergyTargetCalculator.assessManualTarget`); shown in the error.
    static let maximumKcal = 10_000
    private static let maximumDigits = 5

    /// The digits of `text`, in order, at most five: what the field keeps of whatever was typed or pasted.
    static func digits(in text: String) -> String {
        text.compactMap(\.wholeNumberValue).prefix(maximumDigits).map(String.init).joined()
    }

    init(text: String) {
        let digits = Self.digits(in: text)
        guard !digits.isEmpty, let kcal = Int(digits) else {
            self = .empty
            return
        }
        self = EnergyTargetCalculator.assessManualTarget(Double(kcal), sex: nil) == .invalid ? .invalid : .valid(Double(kcal))
    }

    /// The number when there is a usable one.
    var kcal: Double? {
        if case .valid(let kcal) = self { kcal } else { nil }
    }

    /// The text for a saved own number (nothing for a value no field could have produced).
    static func text(forKcal kcal: Double?) -> String {
        guard let kcal, kcal.isFinite, kcal >= 0, kcal < 100_000 else { return "" }
        return String(Int(kcal.rounded()))
    }
}

/// Whether Finish is on for step 7. The step needs a way of having a guide, or of having none:
/// - tracking without a guide is always enough;
/// - a number in the field that cannot be used is never dropped silently, so it blocks Finish (the field is only there, and
///   only counts, while numbers are shown);
/// - otherwise the guide is calculated, or the person's own number, or it still needs one (no sex value and no own number).
///   With numbers hidden the only way out of the last case is to track without a guide.
func dailyGuideStepCanFinish(draft: ProfileDraft, manualText: String?, hideNumbers: Bool, currentYear: Int) -> Bool {
    if draft.tracksWithoutGuide { return true }
    if !hideNumbers, let manualText, ManualTargetInput(text: manualText) == .invalid { return false }
    if case .needsManualTarget? = try? draft.dailyGuide(inYear: currentYear) { return false }
    return true
}

/// Step 7: the daily guide the profile leads to. It is a starting estimate, never a verdict: a calculated number from
/// Mifflin-St Jeor, the person's own number, or none at all. With Hide numbers on it shows no figure of any kind.
struct DailyGuideStep: View {
    @Binding var draft: ProfileDraft
    /// What the person has typed in the own-number field; nil shows the draft's own number. The flow keeps it, because
    /// Finish depends on it.
    @Binding var manualEdit: String?
    let currentYear: Int
    let hideNumbers: Bool
    /// The own number the card and the notice are judged by: the one the person had when they last finished typing. Typing
    /// changes the draft at once (so Finish never loses a number) but not the screen, which would jump with every digit.
    @State private var committedManual: Double?
    @FocusState private var manualFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(draft: Binding<ProfileDraft>, manualEdit: Binding<String?>, currentYear: Int, hideNumbers: Bool) {
        _draft = draft
        _manualEdit = manualEdit
        self.currentYear = currentYear
        self.hideNumbers = hideNumbers
        _committedManual = State(initialValue: draft.wrappedValue.manualTargetKcal)
    }

    /// The guide for what the draft holds now. Nil when the draft is outside what the engine accepts; the earlier steps keep
    /// that from happening.
    private var guide: DailyGuide? { try? draft.dailyGuide(inYear: currentYear) }

    /// The guide for what is on screen: the draft, with the own number as it was when typing last finished.
    private var shownGuide: DailyGuide? {
        var shown = draft
        shown.manualTargetKcal = committedManual
        return try? shown.dailyGuide(inYear: currentYear)
    }

    private var manualInput: ManualTargetInput { ManualTargetInput(text: manualBinding.wrappedValue) }

    var body: some View {
        if hideNumbers {
            hiddenContent
        } else {
            visibleContent
        }
    }

    // MARK: Numbers hidden

    @ViewBuilder
    private var hiddenContent: some View {
        if draft.tracksWithoutGuide {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You're tracking without a guide. Numbers stay hidden.").font(.nuriBodyEmphasis).foregroundStyle(Color.nuriInk)
                    Text("You can change this anytime in You.").nuriSecondaryText()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowBackground(Color.nuriSurface)
                // A person who chose to track without a guide can take it back.
                trackWithoutGuideToggle
            }
        } else if case .needsManualTarget? = guide {
            // Without a sex value nothing can be calculated, and typing a number would show one: the only choice is to go without.
            Section {
                trackWithoutGuideToggle
            } footer: {
                Text("Without a sex value, Nuri can't calculate a guide, and numbers are hidden. Turn on Track without a guide to finish.")
                    .nuriSecondaryText()
            }
        } else {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your daily guide is set. Numbers stay hidden.").font(.nuriBodyEmphasis).foregroundStyle(Color.nuriInk)
                    Text("Review it anytime in You.").nuriSecondaryText()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowBackground(Color.nuriSurface)
            }
        }
    }

    // MARK: Numbers shown

    @ViewBuilder
    private var visibleContent: some View {
        if case .calculated(let estimate)? = shownGuide {
            calculatedSection(estimate)
        } else if case .needsManualTarget? = shownGuide {
            Section {
                Text("Without a sex value, Nuri can't use the formula. Enter your own daily guide or track without one.")
                    .font(.nuriBody)
                    .foregroundStyle(Color.nuriInk)
                    .listRowBackground(Color.nuriSurface)
            }
        }

        // One section for the field whether or not it shows an error: a different section would be a new field, and typing
        // would lose its focus on the first digit that is not a number.
        Section {
            ownNumberRow
        } header: {
            NuriSectionHeader(Text("Use my own number"))
        } footer: {
            if manualInput == .invalid, !draft.tracksWithoutGuide {
                Label {
                    Text("Enter a number from 1 to \(ManualTargetInput.maximumKcal.formatted()) kcal.")
                } icon: {
                    // Not colour alone: the mark says "error" too.
                    Image(systemName: "exclamationmark.circle").accessibilityHidden(true)
                }
                .font(.nuriFootnote)
                .foregroundStyle(Color.nuriDestructive)
            }
        }

        if case .manual(_, .belowRecommendedMinimum(let minimum))? = shownGuide {
            Section {
                NoticeCard(
                    title: Text("That's below the commonly suggested minimum"),
                    message: Text("Many people need at least \(Int(minimum.rounded()).formatted()) kcal a day. Consider talking with a registered dietitian or a clinician.")
                )
                .accessibilityIdentifier("profile.belowMinimumNotice")
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }

        Section { trackWithoutGuideToggle }
    }

    /// The label is the section header (always on screen, unlike a placeholder), so the field's own prompt only says what
    /// goes in it, in the quiet ink (the system's placeholder gray is 1.7:1). The unit sits beside the number and is always
    /// on screen; VoiceOver reads it as part of the value. At accessibility text sizes the unit moves under the field, which
    /// then has the whole row: a prompt does not wrap, so beside the unit it would be cut off.
    private var ownNumberRow: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            ownNumberField
            Text("kcal").font(.nuriBody).foregroundStyle(Color.nuriInkSoft).fixedSize().accessibilityHidden(true)
        }
        .frame(minHeight: NuriMetrics.minTouch)
        .disabled(draft.tracksWithoutGuide)
        .listRowBackground(Color.nuriSurface)
    }

    private var ownNumberField: some View {
        TextField("Use my own number", text: manualBinding, prompt: Text("Daily guide").foregroundStyle(Color.nuriInkSoft), axis: .vertical)
            .lineLimit(1...3)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .font(.nuriBody)
            .foregroundStyle(Color.nuriInk)
            .focused($manualFocused)
            .onSubmit(commitManual)
            .onChange(of: manualFocused) { _, focused in
                if !focused { commitManual() }
            }
            .onChange(of: manualInput == .invalid) { _, invalid in
                if invalid { announceRange() }
            }
            .toolbar {
                // A number pad has no return key: this is how the number is committed.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button { manualFocused = false } label: { Text("Done") }
                        .accessibilityIdentifier("profile.manualTarget.done")
                }
            }
            .accessibilityLabel(Text("Use my own number"))
            .accessibilityValue(spokenManualValue)
            .accessibilityIdentifier("profile.manualTarget")
    }

    private var spokenManualValue: Text {
        let digits = manualBinding.wrappedValue
        return digits.isEmpty ? Text("") : Text("\(digits) kcal")
    }

    /// The number as it is when the person finishes typing: from then on the card and the notice follow it.
    private func commitManual() {
        committedManual = draft.manualTargetKcal
    }

    private func announceRange() {
        AccessibilityNotification.Announcement(String(localized: "Enter a number from 1 to \(ManualTargetInput.maximumKcal.formatted()) kcal.")).post()
    }

    private func calculatedSection(_ estimate: EnergyTargetEstimate) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("About \(Int(estimate.targetKcal.rounded()).formatted()) kcal a day")
                    .font(.nuriTitle2)
                    .foregroundStyle(Color.nuriInk)
                    .accessibilityIdentifier("profile.guideHeadline")
                Text("A starting estimate. Real needs vary.").nuriSecondaryText()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowBackground(Color.nuriSurface)

            LabeledContent {
                value(Text("\(Int(roundTo(estimate.tdeeKcal, step: 10)).formatted()) kcal"))
            } label: { rowTitle(Text("Maintenance estimate")) }
                .accessibilityElement(children: .combine)
                .listRowBackground(Color.nuriSurface)
            LabeledContent {
                if estimate.adjustmentKcal == 0 {
                    value(Text("None"))
                } else {
                    value(Text("\(Int(estimate.adjustmentKcal.rounded()).formatted(.number.sign(strategy: .always()))) kcal"))
                }
            } label: { rowTitle(Text("Goal adjustment")) }
                .accessibilityElement(children: .combine)
                .listRowBackground(Color.nuriSurface)
            LabeledContent {
                value(Text("Mifflin-St Jeor"))
            } label: { rowTitle(Text("Method")) }
                .accessibilityElement(children: .combine)
                .listRowBackground(Color.nuriSurface)

            if estimate.raisedToMinimum {
                Text("Raised to the commonly suggested minimum.").nuriSecondaryText().listRowBackground(Color.nuriSurface)
            }
            if estimate.lossNotAppliedUnderweight {
                Text("A weight-loss adjustment isn't used at your current BMI. Consider talking with a clinician.")
                    .nuriSecondaryText()
                    .listRowBackground(Color.nuriSurface)
            }
        }
    }

    // MARK: Pieces

    private var trackWithoutGuideToggle: some View {
        Toggle(isOn: $draft.tracksWithoutGuide) {
            Text("Track without a guide").font(.nuriBody).foregroundStyle(Color.nuriInk)
        }
        .accessibilityIdentifier("profile.trackWithoutGuide")
        .listRowBackground(Color.nuriSurface)
    }

    /// The text of the own-number field: digits only. A number the engine accepts becomes the draft's manual target at
    /// once; anything else (empty, 0, more than 10,000) leaves no manual target, and the field says why.
    private var manualBinding: Binding<String> {
        Binding(
            get: { manualEdit ?? ManualTargetInput.text(forKcal: draft.manualTargetKcal) },
            set: { text in
                let digits = ManualTargetInput.digits(in: text)
                manualEdit = digits
                draft.manualTargetKcal = ManualTargetInput(text: digits).kcal
            }
        )
    }

    private func rowTitle(_ text: Text) -> some View {
        text.font(.nuriBody).foregroundStyle(Color.nuriInk)
    }

    /// Trailing value of a `LabeledContent` row, in `nuriInkSoft` (the system's gray is under 4.5:1 on white).
    private func value(_ text: Text) -> some View {
        text.font(.nuriBody).foregroundStyle(Color.nuriInkSoft)
    }
}

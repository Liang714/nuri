import DesignSystem
import NuriDomain
import NutritionEngine
import Persistence
import SwiftUI

/// Step 7: the daily guide the profile leads to. It is a starting estimate, never a verdict: a calculated number from
/// Mifflin-St Jeor, the person's own number, or none at all. With Hide numbers on it shows no figure of any kind.
struct DailyGuideStep: View {
    @Binding var draft: ProfileDraft
    let currentYear: Int
    let hideNumbers: Bool
    @State private var manualText: String

    /// The largest own number the engine accepts (see `EnergyTargetCalculator.assessManualTarget`).
    private static let manualRange = 1...10_000

    init(draft: Binding<ProfileDraft>, currentYear: Int, hideNumbers: Bool) {
        _draft = draft
        self.currentYear = currentYear
        self.hideNumbers = hideNumbers
        _manualText = State(initialValue: draft.wrappedValue.manualTargetKcal.map { String(Int($0.rounded())) } ?? "")
    }

    /// Nil when the draft is outside what the engine accepts; the earlier steps keep that from happening.
    private var guide: DailyGuide? { try? draft.dailyGuide(inYear: currentYear) }

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
        if case .needsManualTarget? = guide {
            // Without a sex value nothing can be calculated, and typing a number would show one: the only choice is to go without.
            Section { trackWithoutGuideToggle }
        } else {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your daily guide is set. Numbers stay hidden.").font(.nuriBodyEmphasis).foregroundStyle(Color.nuriInk)
                    Text("Review it anytime in You.").nuriSecondaryText()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowBackground(Color.nuriSurface)
                // A person who chose to track without a guide can take it back.
                if draft.tracksWithoutGuide { trackWithoutGuideToggle }
            }
        }
    }

    // MARK: Numbers shown

    @ViewBuilder
    private var visibleContent: some View {
        if case .calculated(let estimate)? = guide {
            calculatedSection(estimate)
        } else if case .needsManualTarget? = guide {
            Section {
                Text("Without a sex value, Nuri can't use the formula. Enter your own daily guide or track without one.")
                    .font(.nuriBody)
                    .foregroundStyle(Color.nuriInk)
                    .listRowBackground(Color.nuriSurface)
            }
        }

        Section {
            // A vertical axis lets the prompt wrap at accessibility text sizes instead of being cut off.
            TextField("Use my own number", text: manualBinding, axis: .vertical)
                .lineLimit(1...3)
                .keyboardType(.numberPad)
                .font(.nuriBody)
                .foregroundStyle(Color.nuriInk)
                .frame(minHeight: NuriMetrics.minTouch)
                .disabled(draft.tracksWithoutGuide)
                .accessibilityIdentifier("profile.manualTarget")
                .listRowBackground(Color.nuriSurface)
        } footer: {
            Text("Enter a number from 1 to \(Self.manualRange.upperBound.formatted()) kcal.").nuriSecondaryText()
        }

        if case .manual(_, .belowRecommendedMinimum(let minimum))? = guide {
            Section {
                NoticeCard(
                    title: Text("That's below the commonly suggested minimum"),
                    message: Text("Many people need at least \(Int(minimum.rounded()).formatted()) kcal a day. Consider talking with a registered dietitian or a clinician.")
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }

        Section { trackWithoutGuideToggle }
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

    /// The text of the own-number field. A number the engine accepts becomes the draft's manual target; anything else
    /// (empty, 0, more than 10,000) leaves no manual target, so the calculated guide or the sex prompt stays.
    private var manualBinding: Binding<String> {
        Binding(
            get: { manualText },
            set: { text in
                let digits = Array(text.compactMap(\.wholeNumberValue).prefix(5))
                manualText = digits.map(String.init).joined()
                let kcal = digits.reduce(0) { $0 * 10 + $1 }
                draft.manualTargetKcal = Self.manualRange.contains(kcal) ? Double(kcal) : nil
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

import DesignSystem
import NuriDomain
import Persistence
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum ProfileStep: Int, CaseIterable {
    case aboutYou = 1, body, activityLevel, goal, healthQuestions, numbers, dailyGuide

    var title: LocalizedStringKey {
        switch self {
        case .aboutYou: "About you"
        case .body: "Body"
        case .activityLevel: "Activity level"
        case .goal: "Goal"
        case .healthQuestions: "A few health questions"
        case .numbers: "Numbers"
        case .dailyGuide: "Your daily guide"
        }
    }

    var next: ProfileStep? { Self(rawValue: rawValue + 1) }
    var previous: ProfileStep? { Self(rawValue: rawValue - 1) }
}

/// Holds the draft the flow opens with, so the store is read once for as long as the flow is on screen however often its
/// body is evaluated. SwiftUI keeps the first box a `@State` is given and drops later ones.
@MainActor
final class OpeningDraftBox {
    private var opened: ProfileDraft?

    /// The first draft `open` returned; `open` runs only on the first ask.
    func draft(_ open: () -> ProfileDraft) -> ProfileDraft {
        if let opened { return opened }
        let draft = open()
        opened = draft
        return draft
    }
}

/// The seven profile steps, one on screen at a time. It starts from the saved profile when there is one (so running it
/// again never overwrites saved answers with defaults) and from the starting values otherwise.
/// `onFinish` runs after the profile is saved: onboarding moves on, a later edit screen can simply close.
struct ProfileFlow: View {
    @Environment(\.modelContext) private var modelContext
    var currentYear: Int = ProfileCalendar.currentYear()
    var regionCode: String? = Locale.current.region?.identifier
    let onFinish: () -> Void
    @State private var opening = OpeningDraftBox()

    var body: some View {
        // The saved profile is read on the first evaluation only; the editor keeps the draft it is given.
        ProfileEditor(
            initial: opening.draft { .opening(context: modelContext, regionCode: regionCode, currentYear: currentYear) },
            currentYear: currentYear,
            onFinish: onFinish
        )
    }
}

private struct ProfileEditor: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @State private var draft: ProfileDraft
    @State private var step: ProfileStep = .aboutYou
    /// The weight field's text while the person edits it; nil shows the draft's weight.
    @State private var weightEdit: String?
    /// The own-number field's text while the person edits it; nil shows the draft's own number.
    @State private var manualEdit: String?
    @State private var saveFailed = false
    let currentYear: Int
    let onFinish: () -> Void

    init(initial: ProfileDraft, currentYear: Int, onFinish: @escaping () -> Void) {
        _draft = State(initialValue: initial)
        self.currentYear = currentYear
        self.onFinish = onFinish
    }

    private var canContinue: Bool {
        step != .body || bodyStepIsComplete(draft: draft, weightEdit: weightEdit, locale: locale)
    }

    private var canFinish: Bool {
        dailyGuideStepCanFinish(draft: draft, manualText: manualEdit, hideNumbers: appState.hideNumbers, currentYear: currentYear)
    }

    var body: some View {
        NavigationStack {
            List {
                caption
                stepContent
            }
            .id(step)
            .nuriGroupedList()
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("profile.step.\(step.rawValue)")
            .navigationTitle(Text(step.title))
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        }
        .alert(Text("Couldn't save your profile"), isPresented: $saveFailed) {
            Button(role: .cancel) {} label: { Text("OK") }
        } message: {
            Text("Please try again.")
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .aboutYou: AboutYouStep(draft: $draft, currentYear: currentYear)
        case .body: BodyStep(draft: $draft, weightEdit: $weightEdit)
        case .activityLevel: ActivityStep(draft: $draft)
        case .goal: GoalStep(draft: $draft)
        case .healthQuestions: HealthQuestionsStep(draft: $draft)
        case .numbers: NumbersStep()
        case .dailyGuide:
            DailyGuideStep(draft: $draft, manualEdit: $manualEdit, currentYear: currentYear, hideNumbers: appState.hideNumbers)
        }
    }

    /// "Step 2 of 7", the first row of the list: under the title, scrolling with the step.
    private var caption: some View {
        Section {
            Text("Step \(step.rawValue) of \(ProfileStep.allCases.count)")
                .nuriSecondaryText()
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
        }
        .listSectionSpacing(.compact)
    }

    private var actions: some View {
        VStack(spacing: 4) {
            if step.next == nil {
                Button { finish() } label: { Text("Finish") }
                    .buttonStyle(NuriPrimaryButtonStyle())
                    .disabled(!canFinish)
                    .accessibilityIdentifier("profile.finish")
            } else {
                Button { move(to: step.next) } label: { Text("Continue") }
                    .buttonStyle(NuriPrimaryButtonStyle())
                    .disabled(!canContinue)
                    .accessibilityIdentifier("profile.continue")
            }
            if let previous = step.previous {
                Button { move(to: previous) } label: { Text("Back") }
                    .buttonStyle(NuriTextButtonStyle())
                    .accessibilityIdentifier("profile.back")
            }
        }
        .padding(.horizontal, NuriMetrics.screenMargin)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func move(to newStep: ProfileStep?) {
        guard let newStep else { return }
        step = newStep
        #if canImport(UIKit)
        // The title and content change together; tell VoiceOver the screen is new.
        UIAccessibility.post(notification: .screenChanged, argument: nil)
        #endif
    }

    private func finish() {
        do {
            try ProfileRepository(context: modelContext).save(draft, now: .now)
            onFinish()
        } catch {
            saveFailed = true
        }
    }
}

import ActivityEngine
import DesignSystem
import NuriDomain
import Persistence
import SwiftUI

// The profile steps are sections for the flow's list. Each edits the shared draft and shows no number that Hide numbers covers
// (the daily guide step is the only one with calorie figures).

/// A tappable list row with a checkmark when selected: title, optional one-line detail.
private struct SelectionRow: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?
    let selected: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.nuriBodyEmphasis).foregroundStyle(Color.nuriInk)
                    if let detail { Text(detail).nuriSecondaryText() }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark").font(.nuriBodyEmphasis).foregroundStyle(Color.nuriTint).accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: NuriMetrics.minTouch, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
        .listRowBackground(Color.nuriSurface)
    }
}

// MARK: - 1. About you

struct AboutYouStep: View {
    @Binding var draft: ProfileDraft
    let currentYear: Int

    var body: some View {
        Section {
            Picker("Year of birth", selection: $draft.birthYear) {
                // Most recent first; plain digits, never a grouped number like 1,996.
                ForEach(Array(ProfileCalendar.birthYears(currentYear: currentYear).reversed()), id: \.self) { year in
                    Text(verbatim: String(year)).tag(year)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .accessibilityIdentifier("profile.birthYear")
            .listRowBackground(Color.nuriSurface)
        } header: { NuriSectionHeader(Text("Year of birth")) }

        Section {
            Picker("Sex for energy estimates", selection: $draft.sex) {
                Text("Female").tag(SexForEquation?.some(.female))
                Text("Male").tag(SexForEquation?.some(.male))
                Text("Prefer not to say").tag(SexForEquation?.none)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel(Text("Sex for energy estimates"))
            .accessibilityIdentifier("profile.sex")
            .listRowBackground(Color.nuriSurface)
        } header: {
            NuriSectionHeader(Text("Sex for energy estimates"))
        } footer: {
            Text("Only used in the Mifflin-St Jeor formula. Choose Prefer not to say to set your daily guide yourself.").nuriSecondaryText()
        }
    }
}

// MARK: - 2. Body

struct BodyStep: View {
    @Binding var draft: ProfileDraft
    /// What the person has typed in the weight field; nil shows the draft's own weight. Only a valid entry reaches the draft.
    @Binding var weightEdit: String?
    @Environment(\.locale) private var locale

    private var unit: UnitSystem { draft.unitSystem }

    var body: some View {
        Section {
            Picker("Units", selection: unitBinding) {
                Text("Metric").tag(UnitSystem.metric)
                Text("Imperial").tag(UnitSystem.imperial)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel(Text("Units"))
            .accessibilityIdentifier("profile.units")
            .listRowBackground(Color.nuriSurface)
        } header: { NuriSectionHeader(Text("Units")) }

        Section {
            switch unit {
            case .metric: metricHeight
            case .imperial: imperialHeight
            }
        } header: { NuriSectionHeader(Text("Height")) }

        Section {
            TextField("Weight", text: weightBinding)
                .keyboardType(.decimalPad)
                .font(.nuriBody)
                .foregroundStyle(Color.nuriInk)
                .frame(minHeight: NuriMetrics.minTouch)
                .accessibilityIdentifier("profile.weight")
                .listRowBackground(Color.nuriSurface)
        } header: {
            NuriSectionHeader(Text("Weight"))
        } footer: {
            Text("Enter a weight between \(weightBound(\.lowerBound)) and \(weightBound(\.upperBound)).").nuriSecondaryText()
        }
    }

    // MARK: Height

    private var metricHeight: some View {
        let cm = Binding<Int>(
            get: { Int(BodyInput.clampedHeightCm(draft.heightCm).rounded()) },
            set: { draft.heightCm = Double($0) }
        )
        return Stepper(value: cm, in: BodyInput.heightRangeCm, step: 1) {
            Text("\(cm.wrappedValue.formatted()) cm").font(.nuriBody).foregroundStyle(Color.nuriInk)
        }
        .accessibilityIdentifier("profile.heightCm")
        .listRowBackground(Color.nuriSurface)
    }

    private var imperialHeight: some View {
        let current = BodyInput.feetAndInches(cm: draft.heightCm)
        let feet = Binding<Int>(
            get: { current.feet },
            set: { draft.heightCm = BodyInput.heightCm(feet: $0, inches: current.inches) }
        )
        let inches = Binding<Int>(
            get: { current.inches },
            set: { draft.heightCm = BodyInput.heightCm(feet: current.feet, inches: $0) }
        )
        return HStack(spacing: 0) {
            Picker("Height", selection: feet) {
                ForEach(BodyInput.feetChoices, id: \.self) { Text("\($0) ft").tag($0) }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .accessibilityIdentifier("profile.heightFeet")
            Picker("Height", selection: inches) {
                ForEach(BodyInput.inchChoices(forFeet: current.feet), id: \.self) { Text("\($0) in").tag($0) }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .accessibilityIdentifier("profile.heightInches")
        }
        .frame(height: 132)
        .listRowBackground(Color.nuriSurface)
    }

    // MARK: Bindings

    /// Switching units shows the same body in the other unit. Heights are kept as whole centimeters in metric, and any
    /// weight text that was not a valid entry gives way to the last valid weight.
    private var unitBinding: Binding<UnitSystem> {
        Binding(
            get: { draft.unitSystem },
            set: { newValue in
                guard newValue != draft.unitSystem else { return }
                draft.unitSystem = newValue
                if newValue == .metric { draft.heightCm = BodyInput.clampedHeightCm(draft.heightCm).rounded() }
                weightEdit = nil
            }
        )
    }

    private var weightBinding: Binding<String> {
        Binding(
            get: { weightEdit ?? BodyInput.weightText(kg: draft.weightKg, unit: unit, locale: locale) },
            set: { text in
                weightEdit = text
                if let kg = BodyInput.weightKg(from: text, unit: unit, locale: locale), BodyInput.isValidWeight(kg: kg) {
                    draft.weightKg = kg
                }
            }
        )
    }

    /// "30 kg" / "67 lb": a bound of the range in the unit being entered.
    private func weightBound(_ edge: KeyPath<ClosedRange<Int>, Int>) -> String {
        let value = BodyInput.weightBounds(in: unit)[keyPath: edge].formatted()
        switch unit {
        case .metric: return String(localized: "\(value) kg")
        case .imperial: return String(localized: "\(value) lb")
        }
    }
}

/// Whether the Body step has a height and weight the engines accept. An unedited weight is the draft's own, already valid.
func bodyStepIsComplete(draft: ProfileDraft, weightEdit: String?, locale: Locale) -> Bool {
    guard BodyInput.isValidHeight(cm: draft.heightCm) else { return false }
    guard let weightEdit else { return BodyInput.isValidWeight(kg: draft.weightKg) }
    return BodyInput.weightKg(from: weightEdit, unit: draft.unitSystem, locale: locale).map(BodyInput.isValidWeight(kg:)) ?? false
}

// MARK: - 3. Activity level

struct ActivityStep: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        Section {
            ForEach(ActivityLevel.allCases, id: \.self) { level in
                SelectionRow(title: level.title, detail: level.detail, selected: draft.activityLevel == level,
                             identifier: "profile.activity.\(level.rawValue)") { draft.activityLevel = level }
            }
        }
    }
}

private extension ActivityLevel {
    var title: LocalizedStringKey {
        switch self {
        case .sedentary: "Mostly sitting"
        case .lightlyActive: "Lightly active"
        case .moderatelyActive: "Moderately active"
        case .veryActive: "Very active"
        case .extraActive: "Extra active"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .sedentary: "Little exercise, mostly desk work."
        case .lightlyActive: "Light movement or exercise 1–3 days a week."
        case .moderatelyActive: "Exercise 3–5 days a week."
        case .veryActive: "Hard exercise 6–7 days a week."
        case .extraActive: "Physical job or training twice a day."
        }
    }
}

// MARK: - 4. Goal

struct GoalStep: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        Section {
            ForEach(Goal.allCases, id: \.self) { goal in
                SelectionRow(title: goal.title, selected: draft.goal == goal,
                             identifier: "profile.goal.\(goal.rawValue)") { draft.goal = goal }
            }
        }
    }
}

private extension Goal {
    var title: LocalizedStringKey {
        switch self {
        case .maintain: "Keep my weight steady"
        case .gradualLoss: "Lose weight gradually"
        case .gradualGain: "Gain weight gradually"
        case .improveNutrition: "Eat better"
        case .performance: "Support my training"
        case .trackOnly: "Just track, no goal"
        }
    }
}

// MARK: - 5. A few health questions

struct HealthQuestionsStep: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        Section {
            ForEach(ReadinessQuestion.allCases, id: \.self) { question in
                Toggle(isOn: binding(for: question)) {
                    Text(question.title).font(.nuriBody).foregroundStyle(Color.nuriInk)
                }
                .accessibilityIdentifier("profile.readiness.\(question.rawValue)")
                .listRowBackground(Color.nuriSurface)
            }
        } footer: {
            Text("If any of these apply, Nuri suggests a light plan and recommends checking with a clinician first.").nuriSecondaryText()
        }
    }

    private func binding(for question: ReadinessQuestion) -> Binding<Bool> {
        Binding(
            get: { draft.readinessYes.contains(question) },
            set: { isYes in
                if isYes { draft.readinessYes.insert(question) } else { draft.readinessYes.remove(question) }
            }
        )
    }
}

private extension ReadinessQuestion {
    var title: LocalizedStringKey {
        switch self {
        case .heartCondition: "A doctor has said I have a heart condition"
        case .chestPainDuringActivity: "I feel chest pain during physical activity"
        case .dizzinessOrFainting: "I lose balance from dizziness or have fainted recently"
        case .boneOrJointProblem: "I have a bone or joint problem that activity could worsen"
        case .bloodPressureMedication: "I take medicine for blood pressure or a heart condition"
        case .pregnancy: "I am pregnant or gave birth in the last six months"
        case .otherMedicalReason: "I know of another reason I should not be active without advice"
        }
    }
}

// MARK: - 6. Numbers

struct NumbersStep: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: { appState.hideNumbers }, set: { appState.setHideNumbers($0) })) {
                Text("Hide numbers").font(.nuriBody).foregroundStyle(Color.nuriInk)
            }
            .accessibilityIdentifier("profile.hideNumbers")
            .listRowBackground(Color.nuriSurface)
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Hides calories, nutrients, grams, minutes and ads everywhere in Nuri.")
                Text("You can change this anytime in You.")
            }
            .nuriSecondaryText()
        }
    }
}

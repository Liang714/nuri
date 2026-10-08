import Testing
import NuriDomain
import NutritionEngine
@testable import ActivityEngine

@Suite struct MovementPlannerTests {
    let catalog = try! METCatalog.bundled()
    let base = BodyProfile(ageYears: 30, sex: .male, heightCm: 180, weightKg: 80,
                           activityLevel: .moderatelyActive, goal: .maintain)

    func plan(_ edit: (inout MovementPlanInput) -> Void = { _ in }) throws -> MovementPlan {
        var input = MovementPlanInput(profile: base, bmiStandard: .who)
        edit(&input)
        return try MovementPlanner.plan(input, catalog: catalog)
    }

    func aerobic(_ p: MovementPlan) -> PlanItem? { p.items.first { $0.kind == .aerobic } }

    @Test func invalidProfileThrows() {
        var input = MovementPlanInput(profile: base, bmiStandard: .who)
        input.profile.ageYears = 17
        #expect(throws: ProfileValidationError.ageOutOfRange(17)) {
            try MovementPlanner.plan(input, catalog: catalog)
        }
    }

    @Test func spikeCapBindingAtFullTargetAddsProgressingGradually() throws {
        // Moderately active, maintain: this week's target equals the goal (150). Two days left and nothing done
        // → an even share would be 75 min, above the spike cap of 45 → trimmed, with progressingGradually.
        let p = try plan { $0.daysRemainingInWeekIncludingToday = 2 }
        #expect(p.weekly.thisWeekMinutes == p.weekly.goalMinutes)
        #expect(p.notices.contains(.progressingGradually))
        #expect(!p.rationale.contains(.progressionTenPercent))
        let a = try #require(aerobic(p))
        #expect(a.minutesLow == 40 && a.minutesHigh == 50) // 45 min ± 10%
    }

    @Test func baselinePlan() throws {
        let p = try plan()
        #expect(p.weekly.goalMinutes == 150 && p.weekly.thisWeekMinutes == 150)
        let a = try #require(aerobic(p))
        #expect(a.activityId == "walking" && a.intensity == .moderate)
        #expect(a.minutesLow == 25 && a.minutesHigh == 30) // 150/7 = 21.4 → 25
        let kcal = try #require(a.kcal)
        #expect(approx(kcal.estimate, 3.5 * 80 * 25 / 60))
        #expect(p.items.contains { $0.kind == .strength && $0.activityId == "strength_bodyweight" })
        #expect(p.rationale.contains(.whoPhysicalActivity2020))
    }

    @Test func sedentaryBeginnerProgressesGradually() throws {
        let p = try plan { $0.profile.activityLevel = .sedentary }
        #expect(p.weekly.thisWeekMinutes == 60)
        #expect(aerobic(p)?.minutesLow == 10)
        #expect(p.notices.contains(.progressingGradually))
        #expect(p.rationale.contains(.progressionTenPercent))
    }

    @Test func readinessYesGivesClearancePlanOnly() throws {
        let p = try plan { $0.readiness = ReadinessScreen(yesAnswers: [.heartCondition]) }
        #expect(p.items.count == 1)
        let a = try #require(p.items.first)
        #expect(a.activityId == "walking" && a.intensity == .light)
        #expect(a.minutesLow == 10 && a.minutesHigh == 20 && a.kcal == nil)
        #expect(p.notices == [.clinicianClearanceRecommended])
    }

    @Test func onlyTheBindingTimeLimitIsReported() throws {
        // Two days left → 45 min today (spike cap). A 30-min session cap and 20 min available: the budget binds.
        let short = try plan {
            $0.daysRemainingInWeekIncludingToday = 2
            $0.maxSessionMinutes = 30
            $0.availableMinutesToday = 20
        }
        let a = try #require(aerobic(short))
        #expect(a.minutesLow == 20 && a.minutesHigh == 20)
        #expect(short.notices.contains(.limitedByAvailableTime))
        #expect(!short.notices.contains(.cappedAtSessionMaximum))
        // Same cap with 60 min available: the session cap binds, and strength still fits afterwards.
        let roomy = try plan {
            $0.daysRemainingInWeekIncludingToday = 2
            $0.maxSessionMinutes = 30
            $0.availableMinutesToday = 60
        }
        let b = try #require(aerobic(roomy))
        #expect(b.minutesLow == 25 && b.minutesHigh == 30)
        #expect(roomy.notices.contains(.cappedAtSessionMaximum))
        #expect(!roomy.notices.contains(.limitedByAvailableTime))
        #expect(roomy.items.contains { $0.kind == .strength })
    }

    @Test func clearancePlanRespectsAvailableTime() throws {
        let none = try plan {
            $0.readiness = ReadinessScreen(yesAnswers: [.heartCondition])
            $0.availableMinutesToday = 5
        }
        #expect(none.items.isEmpty)
        #expect(none.notices == [.clinicianClearanceRecommended, .limitedByAvailableTime])

        let short = try plan {
            $0.readiness = ReadinessScreen(yesAnswers: [.heartCondition])
            $0.availableMinutesToday = 15
        }
        let a = try #require(short.items.first)
        #expect(a.minutesLow == 10 && a.minutesHigh == 15)
        #expect(short.notices == [.clinicianClearanceRecommended, .limitedByAvailableTime])
    }

    @Test func clearancePlanRespectsSessionCap() throws {
        let p = try plan {
            $0.readiness = ReadinessScreen(yesAnswers: [.heartCondition])
            $0.maxSessionMinutes = 10
        }
        let a = try #require(p.items.first)
        #expect(a.minutesLow == 10 && a.minutesHigh == 10)
        #expect(p.notices == [.clinicianClearanceRecommended, .cappedAtSessionMaximum])
    }

    @Test func clearancePlanWithoutUsableActivityExplainsWhy() throws {
        let p = try plan {
            $0.readiness = ReadinessScreen(yesAnswers: [.heartCondition])
            $0.mobility = [.seatedOnly] // no stationary bike
        }
        #expect(p.items.isEmpty)
        #expect(p.notices == [.clinicianClearanceRecommended, .noSuitableActivity])
    }

    @Test func seatedWithoutEquipmentGetsNoSuitableActivityNotice() throws {
        let p = try plan { $0.mobility = [.seatedOnly] }
        #expect(p.items.isEmpty)
        #expect(p.notices.contains(.noSuitableActivity))
    }

    @Test func strengthDroppedForTimeIsExplained() throws {
        // 25–30 min aerobic uses the whole 30 minutes, so the due strength session does not fit.
        let p = try plan { $0.availableMinutesToday = 30 }
        let a = try #require(aerobic(p))
        #expect(a.minutesLow == 25 && a.minutesHigh == 30)
        #expect(!p.items.contains { $0.kind == .strength })
        #expect(p.notices.contains(.limitedByAvailableTime))
    }

    @Test func balanceDroppedForTimeIsExplained() throws {
        // Age 70, 50 min: aerobic 25–30, strength 15–20, then no time for balance.
        let p = try plan { $0.profile.ageYears = 70; $0.availableMinutesToday = 50 }
        let s = try #require(p.items.first { $0.kind == .strength })
        #expect(s.minutesLow == 15 && s.minutesHigh == 20)
        #expect(!p.items.contains { $0.kind == .balance })
        #expect(p.notices == [.limitedByAvailableTime])
    }

    @Test func limitedByAvailableTimeIsNeverDuplicated() throws {
        let p = try plan { $0.availableMinutesToday = 20; $0.daysRemainingInWeekIncludingToday = 2 }
        #expect(p.notices.filter { $0 == .limitedByAvailableTime }.count == 1)
    }

    @Test func underweightNeverGetsLossPlan() throws {
        let p = try plan {
            $0.profile = BodyProfile(ageYears: 25, sex: .female, heightCm: 170, weightKg: 45,
                                     activityLevel: .moderatelyActive, goal: .gradualLoss)
        }
        #expect(p.notices.contains(.underweightNoLossPlan))
        #expect(p.weekly.goalMinutes == 150)
        #expect(!p.rationale.contains(.acsmWeightManagement2009))
    }

    @Test func lossPlanUsesActivityShare() throws {
        let p = try plan {
            $0.profile.weightKg = 70
            $0.profile.goal = .gradualLoss
            $0.week.previousWeekModerateEquivalentMinutes = 200
        }
        #expect(p.weekly.goalMinutes == 215)
        #expect(p.weekly.thisWeekMinutes == 215)
        #expect(p.rationale.contains(.acsmWeightManagement2009))
    }

    @Test func sensitiveModeHidesAllKcal() throws {
        let p = try plan { $0.sensitiveMode = true }
        #expect(!p.items.isEmpty)
        #expect(p.items.allSatisfy { $0.kcal == nil })
        #expect(!p.rationale.contains(.metCompendium))
    }

    @Test func dayTotalNeverExceeds90Minutes() throws {
        let p = try plan {
            $0.profile.activityLevel = .veryActive
            $0.profile.goal = .performance
            $0.preferredActivityIds = ["walking"]
            $0.daysRemainingInWeekIncludingToday = 1
            $0.week.previousWeekModerateEquivalentMinutes = 300
        }
        // 300 owed on the last day → spike cap 90 → default 60-minute session cap → 55–60.
        let a = try #require(aerobic(p))
        #expect(a.activityId == "walking" && a.intensity == .moderate && a.met == 3.5)
        #expect(a.minutesLow == 55 && a.minutesHigh == 60)
        #expect(p.notices.contains(.cappedAtSessionMaximum))
        let s = try #require(p.items.first { $0.kind == .strength })
        #expect(s.minutesLow == 15 && s.minutesHigh == 25)
        #expect(p.items.map(\.minutesHigh).reduce(0, +) <= MovementPlanner.dailyMaxMinutes)
    }

    @Test func sessionCapIsClampedTo10Through90() throws {
        func lastDayWalking(maxSession: Int) throws -> MovementPlan {
            try plan {
                $0.profile.activityLevel = .veryActive
                $0.profile.goal = .performance
                $0.preferredActivityIds = ["walking"]
                $0.daysRemainingInWeekIncludingToday = 1
                $0.week.previousWeekModerateEquivalentMinutes = 300
                $0.maxSessionMinutes = maxSession
            }
        }
        let low = try lastDayWalking(maxSession: 5) // treated as 10
        let a = try #require(aerobic(low))
        #expect(a.minutesLow == 10 && a.minutesHigh == 10)
        #expect(low.notices.contains(.cappedAtSessionMaximum))

        let high = try lastDayWalking(maxSession: 120) // treated as 90; the spike cap (90) does not exceed it
        let b = try #require(aerobic(high))
        #expect(b.minutesLow == 80 && b.minutesHigh == 90)
        #expect(!high.notices.contains(.cappedAtSessionMaximum))
        #expect(high.items.map(\.minutesHigh).reduce(0, +) <= MovementPlanner.dailyMaxMinutes)
    }

    @Test func sessionCapAppliesToActualVigorousMinutes() throws {
        func lastDayRunning(maxSession: Int) throws -> MovementPlan {
            try plan {
                $0.profile.activityLevel = .veryActive
                $0.profile.goal = .performance
                $0.preferredActivityIds = ["running"]
                $0.daysRemainingInWeekIncludingToday = 1
                $0.week.previousWeekModerateEquivalentMinutes = 300
                $0.maxSessionMinutes = maxSession
            }
        }
        // 90 moderate-equivalent → 45 vigorous minutes, which fits a 45-minute session.
        let fits = try #require(aerobic(try lastDayRunning(maxSession: 45)))
        #expect(fits.intensity == .vigorous && fits.minutesLow == 40 && fits.minutesHigh == 45)
        #expect(try !lastDayRunning(maxSession: 45).notices.contains(.cappedAtSessionMaximum))
        // A 30-minute session cap binds on the 45 vigorous minutes.
        let capped = try lastDayRunning(maxSession: 30)
        let c = try #require(aerobic(capped))
        #expect(c.minutesLow == 25 && c.minutesHigh == 30)
        #expect(capped.notices.contains(.cappedAtSessionMaximum))
    }

    @Test func olderAdultDayTotalWithin90() throws {
        let p = try plan { $0.profile.ageYears = 70 }
        let a = try #require(aerobic(p))
        #expect(a.minutesLow == 25 && a.minutesHigh == 30)
        let s = try #require(p.items.first { $0.kind == .strength })
        #expect(s.minutesLow == 15 && s.minutesHigh == 25)
        let b = try #require(p.items.first { $0.kind == .balance })
        #expect(b.minutesLow == 10 && b.minutesHigh == 15)
        #expect(p.items.map(\.minutesHigh).reduce(0, +) <= MovementPlanner.dailyMaxMinutes)
    }

    @Test func sedentaryPreferringRunningGetsNonVigorousActivity() throws {
        let p = try plan {
            $0.profile.activityLevel = .sedentary
            $0.preferredActivityIds = ["running"]
        }
        let a = try #require(aerobic(p))
        #expect(a.activityId == "walking")
        #expect(a.met < 6)
        #expect(a.intensity != .vigorous)
    }

    @Test func lightlyActiveCyclistGetsLightColumnLabelledByMET() throws {
        let p = try plan {
            $0.profile.activityLevel = .lightlyActive
            $0.preferredActivityIds = ["cycling_outdoor"]
            $0.equipment = ["bicycle"]
        }
        let a = try #require(aerobic(p))
        // The catalog "light" column (4.0 MET) is used, but 4.0 MET is moderate by the MET band.
        #expect(a.activityId == "cycling_outdoor" && a.intensity == .moderate && a.met == 4.0)
    }

    @Test func obeseStationaryCyclistStaysBelow6MET() throws {
        let p = try plan {
            $0.profile.heightCm = 170
            $0.profile.weightKg = 80
            $0.bmiStandard = .asianPacific
            $0.preferredActivityIds = ["cycling_stationary"]
            $0.equipment = ["stationary_bike"]
        }
        let a = try #require(aerobic(p))
        #expect(a.activityId == "cycling_stationary" && a.met == 3.5 && a.intensity == .moderate)
    }

    @Test func performanceWalkingIsModerateNotVigorous() throws {
        let p = try plan {
            $0.profile.activityLevel = .veryActive
            $0.profile.goal = .performance
        }
        let a = try #require(aerobic(p))
        #expect(a.activityId == "walking" && a.intensity == .moderate && a.met == 3.5)
    }

    @Test func underweightPerformanceGetsMaintenancePlan() throws {
        let p = try plan {
            $0.profile = BodyProfile(ageYears: 25, sex: .female, heightCm: 170, weightKg: 45,
                                     activityLevel: .moderatelyActive, goal: .performance)
            $0.preferredActivityIds = ["running"]
        }
        #expect(p.notices.contains(.underweightNoLossPlan))
        #expect(p.weekly.goalMinutes == 150)
        #expect(p.weekly.strengthSessions == 2) // performance is treated as maintain: 2 sessions, not 3
        let a = try #require(aerobic(p))
        #expect(a.activityId == "walking")
        #expect(!p.items.contains { $0.intensity == .vigorous })
    }

    @Test func underweightMaintainGetsClinicianNotice() throws {
        let p = try plan {
            $0.profile = BodyProfile(ageYears: 25, sex: .female, heightCm: 170, weightKg: 45,
                                     activityLevel: .moderatelyActive, goal: .maintain)
        }
        #expect(p.notices.contains(.underweightNoLossPlan))
    }

    @Test func lastDayDoesNotSpike() throws {
        let p = try plan {
            $0.profile.activityLevel = .sedentary
            $0.daysRemainingInWeekIncludingToday = 1
        }
        let a = try #require(aerobic(p))
        #expect(a.minutesHigh <= 20)
        #expect(p.notices.contains(.progressingGradually))
    }

    @Test func tinyAvailableTimeGivesNoAerobicItem() throws {
        let p = try plan { $0.availableMinutesToday = 3 }
        #expect(aerobic(p) == nil)
        #expect(p.notices.contains(.limitedByAvailableTime))
        #expect(!p.items.contains { $0.kind == .strength || $0.kind == .balance })
    }

    @Test func daysRemainingOutOfRangeIsClamped() throws {
        let zero = try plan { $0.daysRemainingInWeekIncludingToday = 0 }
        let one = try plan { $0.daysRemainingInWeekIncludingToday = 1 }
        #expect(aerobic(zero) != nil)
        #expect(aerobic(zero) == aerobic(one))
    }

    @Test func availableTimeLimitsPlanAndSkipsStrength() throws {
        let p = try plan { $0.availableMinutesToday = 20; $0.daysRemainingInWeekIncludingToday = 2 }
        let a = try #require(aerobic(p))
        #expect(a.minutesHigh <= 20)
        #expect(p.notices.contains(.limitedByAvailableTime))
        #expect(!p.items.contains { $0.kind == .strength })
    }

    @Test func obeseBMIGetsLowImpactEvenIfRunningPreferred() throws {
        let p = try plan {
            $0.profile.heightCm = 170
            $0.profile.weightKg = 80 // 27.7: obese by Asian-Pacific cutoffs
            $0.bmiStandard = .asianPacific
            $0.preferredActivityIds = ["running"]
        }
        #expect(aerobic(p)?.activityId == "walking")
        #expect(p.notices.contains(.lowImpactSelected))
    }

    @Test func weeklyGoalReachedOmitsAerobic() throws {
        let p = try plan { $0.week.moderateEquivalentMinutes = 160 }
        #expect(aerobic(p) == nil)
        #expect(p.notices.contains(.weeklyGoalReached))
    }

    @Test func olderAdultsGetBalance() throws {
        let p = try plan { $0.profile.ageYears = 70 }
        #expect(p.items.contains { $0.kind == .balance && $0.activityId == "tai_chi" })
        // Tai chi's only catalog value is 3.0 MET, which is moderate by the MET band.
        #expect(p.items.contains { $0.kind == .balance && $0.met == 3.0 && $0.intensity == .moderate })
    }

    @Test func performanceAllowsVigorousWithHalvedMinutes() throws {
        let p = try plan {
            $0.profile.activityLevel = .veryActive
            $0.profile.goal = .performance
            $0.preferredActivityIds = ["running"]
        }
        let a = try #require(aerobic(p))
        #expect(a.activityId == "running" && a.intensity == .vigorous)
        #expect(a.minutesLow == 10 && a.minutesHigh == 15) // 25 moderate-equivalent → 12.5 vigorous
    }

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

    @Test func sessionCapNoticeFromStrengthWhenAerobicIsOmitted() throws {
        // Weekly goal reached → no aerobic item, so the notice can only come from the strength block.
        let shortened = try plan { $0.week.moderateEquivalentMinutes = 160; $0.maxSessionMinutes = 20 }
        #expect(aerobic(shortened) == nil)
        let s = try #require(shortened.items.first { $0.kind == .strength })
        #expect(s.minutesLow == 15 && s.minutesHigh == 20)
        #expect(shortened.notices.filter { $0 == .cappedAtSessionMaximum }.count == 1)

        let dropped = try plan { $0.week.moderateEquivalentMinutes = 160; $0.maxSessionMinutes = 10 }
        #expect(!dropped.items.contains { $0.kind == .strength })
        #expect(dropped.notices.filter { $0 == .cappedAtSessionMaximum }.count == 1)
        #expect(!dropped.notices.contains(.limitedByAvailableTime))
    }

    @Test func sessionCapNoticeFromBalanceWhenAerobicIsOmitted() throws {
        // Strength is not due (two sessions done), so only the balance block can report the cap.
        let p = try plan {
            $0.profile.ageYears = 70
            $0.week.moderateEquivalentMinutes = 160
            $0.week.strengthSessions = 2
            $0.maxSessionMinutes = 12
        }
        #expect(p.items.count == 1)
        let b = try #require(p.items.first { $0.kind == .balance })
        #expect(b.minutesLow == 10 && b.minutesHigh == 12)
        #expect(p.notices.filter { $0 == .cappedAtSessionMaximum }.count == 1)
    }

    @Test func strengthShortenedByBudgetIsNotReportedAsSessionCap() throws {
        // 20 min available, default 60-minute cap: the budget binds, as before (silent shortening, no cap notice).
        let p = try plan { $0.week.moderateEquivalentMinutes = 160; $0.availableMinutesToday = 20 }
        let s = try #require(p.items.first { $0.kind == .strength })
        #expect(s.minutesLow == 15 && s.minutesHigh == 20)
        #expect(!p.notices.contains(.cappedAtSessionMaximum))
        // Budget below 15 drops it: still limitedByAvailableTime, even with a tight cap as well.
        let dropped = try plan {
            $0.week.moderateEquivalentMinutes = 160
            $0.availableMinutesToday = 12
            $0.maxSessionMinutes = 10
        }
        #expect(!dropped.items.contains { $0.kind == .strength })
        #expect(dropped.notices.contains(.limitedByAvailableTime))
        #expect(!dropped.notices.contains(.cappedAtSessionMaximum))
    }

    @Test func strengthSkippedRightAfterStrengthDayWhenTimeRemains() throws {
        let p = try plan { $0.week.didStrengthYesterday = true }
        #expect(!p.items.contains { $0.kind == .strength })
    }

    /// 20,000 deterministic pseudo-random inputs across every planner input; each plan must satisfy the
    /// safety invariants. Violations are collected and reported together (fast, one expectation).
    @Test func invariantSweep() throws {
        var rng = SplitMix64(seed: 0x4E55_5249)
        let preferences: [[String]] = [[], ["running"], ["walking"], ["cycling_outdoor"], ["cycling_stationary"],
                                       ["swimming", "dancing"], ["elliptical"], ["strength_weights"], ["unknown"]]
        let equipments: [Set<String>] = [[], ["bicycle"], ["stationary_bike"], ["pool", "weights"],
                                         ["bicycle", "stationary_bike", "pool", "elliptical", "weights"]]
        let mobilities: [Set<MobilityPreference>] = [[], [.lowImpactOnly], [.seatedOnly], [.lowImpactOnly, .seatedOnly]]
        let available: [Int?] = [nil, -5, 0, 5, 9, 10, 15, 20, 30, 45, 60, 90, 120]
        let previousWeeks: [Double?] = [nil, 0, 30, 100, 200, 300, 1000, .infinity]
        var violations: [String] = []
        var seen: [String: Int] = [:]

        for n in 0..<20_000 {
            let profile = BodyProfile(
                ageYears: [18, 30, 64, 65, 80, 120].randomElement(using: &rng)!,
                sex: [SexForEquation.male, .female, nil].randomElement(using: &rng)!,
                heightCm: [150.0, 170, 190].randomElement(using: &rng)!,
                weightKg: [40.0, 50, 60, 70, 80, 95, 120, 160].randomElement(using: &rng)!,
                activityLevel: ActivityLevel.allCases.randomElement(using: &rng)!,
                goal: Goal.allCases.randomElement(using: &rng)!)
            let clearance = Int.random(in: 0..<4, using: &rng) == 0
            let input = MovementPlanInput(
                profile: profile,
                bmiStandard: BMIStandard.allCases.randomElement(using: &rng)!,
                readiness: ReadinessScreen(yesAnswers: clearance ? [.boneOrJointProblem] : []),
                preferredActivityIds: preferences.randomElement(using: &rng)!,
                equipment: equipments.randomElement(using: &rng)!,
                mobility: mobilities.randomElement(using: &rng)!,
                availableMinutesToday: available.randomElement(using: &rng)!,
                week: WeeklyActivitySummary(
                    moderateEquivalentMinutes: [0.0, 30, 100, 160, 300].randomElement(using: &rng)!,
                    strengthSessions: Int.random(in: 0...3, using: &rng),
                    balanceSessions: Int.random(in: 0...3, using: &rng),
                    didStrengthYesterday: Bool.random(using: &rng),
                    previousWeekModerateEquivalentMinutes: previousWeeks.randomElement(using: &rng)!),
                daysRemainingInWeekIncludingToday: Int.random(in: 0...8, using: &rng),
                lossDeficitKcal: [0.0, 250, 500, 2000, .nan].randomElement(using: &rng)!,
                activityShareOfDeficit: [0.0, 0.25, 0.5, 1].randomElement(using: &rng)!,
                sensitiveMode: Bool.random(using: &rng),
                maxSessionMinutes: [0, 5, 10, 15, 20, 30, 45, 60, 90, 120].randomElement(using: &rng)!)
            let p = try MovementPlanner.plan(input, catalog: catalog)

            let category = BMI.category(for: BMI.value(weightKg: profile.weightKg, heightCm: profile.heightCm),
                                        standard: input.bmiStandard)
            let budget = max(0, min(90, input.availableMinutesToday ?? 90))
            let sessionCap = min(90, max(10, input.maxSessionMinutes))
            let vigorousAllowed = !clearance && profile.activityLevel >= .moderatelyActive
                && profile.goal == .performance && (category == .normal || category == .overweight)
            func fail(_ what: String) { violations.append("#\(n) \(what): \(input) → \(p)") }

            if p.items.reduce(0, { $0 + $1.minutesHigh }) > budget { fail("day total over budget") }
            for item in p.items {
                let activity = catalog.activity(id: item.activityId)
                if item.minutesLow < 1 || item.minutesLow > item.minutesHigh { fail("bad range") }
                if item.minutesHigh > sessionCap { fail("\(item.kind) over session cap") }
                if item.intensity != Intensity.forMET(item.met) { fail("label is not the MET band") }
                if item.intensity == .vigorous {
                    seen["vigorous", default: 0] += 1
                    if !vigorousAllowed { fail("vigorous not allowed") }
                }
                // Clearance plans never carry kcal either (minutes-only light plan).
                if (item.kcal == nil) != (input.sensitiveMode || clearance) { fail("kcal visibility") }
                if category == .obese && item.kind == .aerobic && activity?.isLowImpact != true { fail("not low impact") }
                if input.mobility.contains(.seatedOnly) && activity?.isSeated != true { fail("not seated") }
            }
            if category == .underweight && !clearance && !p.notices.contains(.underweightNoLossPlan) {
                fail("underweight notice missing")
            }
            if Set(p.notices).count != p.notices.count { fail("duplicate notice") }
            if p.items.isEmpty && p.notices.isEmpty { fail("silent empty plan") }
            for notice in p.notices { seen["\(notice)", default: 0] += 1 }
        }

        #expect(violations.isEmpty, "\(violations.count) violations, first: \(violations.prefix(3))")
        // The sweep must actually reach the interesting paths.
        for key in ["vigorous", "cappedAtSessionMaximum", "limitedByAvailableTime", "noSuitableActivity",
                    "clinicianClearanceRecommended", "underweightNoLossPlan", "lowImpactSelected"] {
            #expect(seen[key, default: 0] > 0, "\(key) never reached")
        }
    }
}

/// Deterministic generator for the invariant sweep (SplitMix64).
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

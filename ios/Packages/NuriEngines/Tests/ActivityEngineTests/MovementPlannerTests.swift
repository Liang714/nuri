import Testing
import NuriDomain
import NutritionEngine
@testable import ActivityEngine

@Suite struct MovementPlannerTests {
    let catalog = try! METCatalog.bundled()
    let base = BodyProfile(ageYears: 30, sex: .male, heightCm: 180, weightKg: 80,
                           activityLevel: .moderatelyActive, goal: .maintain)

    func plan(_ edit: (inout MovementPlanInput) -> Void = { _ in }) -> MovementPlan {
        var input = MovementPlanInput(profile: base, bmiStandard: .who)
        edit(&input)
        return MovementPlanner.plan(input, catalog: catalog)
    }

    func aerobic(_ p: MovementPlan) -> PlanItem? { p.items.first { $0.kind == .aerobic } }

    @Test func baselinePlan() throws {
        let p = plan()
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
        let p = plan { $0.profile.activityLevel = .sedentary }
        #expect(p.weekly.thisWeekMinutes == 60)
        #expect(aerobic(p)?.minutesLow == 10)
        #expect(p.notices.contains(.progressingGradually))
        #expect(p.rationale.contains(.progressionTenPercent))
    }

    @Test func readinessYesGivesClearancePlanOnly() throws {
        let p = plan { $0.readiness = ReadinessScreen(yesAnswers: [.heartCondition]) }
        #expect(p.items.count == 1)
        let a = try #require(p.items.first)
        #expect(a.activityId == "walking" && a.intensity == .light)
        #expect(a.minutesLow == 10 && a.minutesHigh == 20 && a.kcal == nil)
        #expect(p.notices == [.clinicianClearanceRecommended])
    }

    @Test func underweightNeverGetsLossPlan() {
        let p = plan {
            $0.profile = BodyProfile(ageYears: 25, sex: .female, heightCm: 170, weightKg: 45,
                                     activityLevel: .moderatelyActive, goal: .gradualLoss)
        }
        #expect(p.notices.contains(.underweightNoLossPlan))
        #expect(p.weekly.goalMinutes == 150)
        #expect(!p.rationale.contains(.acsmWeightManagement2009))
    }

    @Test func lossPlanUsesActivityShare() {
        let p = plan {
            $0.profile.weightKg = 70
            $0.profile.goal = .gradualLoss
            $0.week.previousWeekModerateEquivalentMinutes = 200
        }
        #expect(p.weekly.goalMinutes == 215)
        #expect(p.weekly.thisWeekMinutes == 215)
        #expect(p.rationale.contains(.acsmWeightManagement2009))
    }

    @Test func sensitiveModeHidesAllKcal() {
        let p = plan { $0.sensitiveMode = true }
        #expect(!p.items.isEmpty)
        #expect(p.items.allSatisfy { $0.kcal == nil })
        #expect(!p.rationale.contains(.metCompendium))
    }

    @Test func dayTotalNeverExceeds90Minutes() throws {
        let p = plan {
            $0.profile.activityLevel = .veryActive
            $0.profile.goal = .performance
            $0.preferredActivityIds = ["walking"]
            $0.daysRemainingInWeekIncludingToday = 1
            $0.week.previousWeekModerateEquivalentMinutes = 300
        }
        let a = try #require(aerobic(p))
        #expect(a.activityId == "walking" && a.intensity == .moderate && a.met == 3.5)
        #expect(a.minutesLow == 80 && a.minutesHigh == 90)
        #expect(!p.items.contains { $0.kind == .strength })
        #expect(p.items.map(\.minutesHigh).reduce(0, +) <= MovementPlanner.dailyMaxMinutes)
    }

    @Test func olderAdultDayTotalWithin90() throws {
        let p = plan { $0.profile.ageYears = 70 }
        let a = try #require(aerobic(p))
        #expect(a.minutesLow == 25 && a.minutesHigh == 30)
        let s = try #require(p.items.first { $0.kind == .strength })
        #expect(s.minutesLow == 15 && s.minutesHigh == 25)
        let b = try #require(p.items.first { $0.kind == .balance })
        #expect(b.minutesLow == 10 && b.minutesHigh == 15)
        #expect(p.items.map(\.minutesHigh).reduce(0, +) <= MovementPlanner.dailyMaxMinutes)
    }

    @Test func sedentaryPreferringRunningGetsNonVigorousActivity() throws {
        let p = plan {
            $0.profile.activityLevel = .sedentary
            $0.preferredActivityIds = ["running"]
        }
        let a = try #require(aerobic(p))
        #expect(a.activityId == "walking")
        #expect(a.met < 6)
        #expect(a.intensity != .vigorous)
    }

    @Test func lightlyActiveCyclistGetsLightColumnLabelledByMET() throws {
        let p = plan {
            $0.profile.activityLevel = .lightlyActive
            $0.preferredActivityIds = ["cycling_outdoor"]
            $0.equipment = ["bicycle"]
        }
        let a = try #require(aerobic(p))
        // The catalog "light" column (4.0 MET) is used, but 4.0 MET is moderate by the MET band.
        #expect(a.activityId == "cycling_outdoor" && a.intensity == .moderate && a.met == 4.0)
    }

    @Test func obeseStationaryCyclistStaysBelow6MET() throws {
        let p = plan {
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
        let p = plan {
            $0.profile.activityLevel = .veryActive
            $0.profile.goal = .performance
        }
        let a = try #require(aerobic(p))
        #expect(a.activityId == "walking" && a.intensity == .moderate && a.met == 3.5)
    }

    @Test func underweightPerformanceGetsMaintenancePlan() throws {
        let p = plan {
            $0.profile = BodyProfile(ageYears: 25, sex: .female, heightCm: 170, weightKg: 45,
                                     activityLevel: .moderatelyActive, goal: .performance)
            $0.preferredActivityIds = ["running"]
        }
        #expect(p.notices.contains(.underweightNoLossPlan))
        #expect(p.weekly.goalMinutes == 150)
        let a = try #require(aerobic(p))
        #expect(a.activityId == "walking")
        #expect(!p.items.contains { $0.intensity == .vigorous })
    }

    @Test func underweightMaintainGetsClinicianNotice() {
        let p = plan {
            $0.profile = BodyProfile(ageYears: 25, sex: .female, heightCm: 170, weightKg: 45,
                                     activityLevel: .moderatelyActive, goal: .maintain)
        }
        #expect(p.notices.contains(.underweightNoLossPlan))
    }

    @Test func lastDayDoesNotSpike() throws {
        let p = plan {
            $0.profile.activityLevel = .sedentary
            $0.daysRemainingInWeekIncludingToday = 1
        }
        let a = try #require(aerobic(p))
        #expect(a.minutesHigh <= 20)
        #expect(p.notices.contains(.progressingGradually))
    }

    @Test func tinyAvailableTimeGivesNoAerobicItem() {
        let p = plan { $0.availableMinutesToday = 3 }
        #expect(aerobic(p) == nil)
        #expect(p.notices.contains(.limitedByAvailableTime))
        #expect(!p.items.contains { $0.kind == .strength || $0.kind == .balance })
    }

    @Test func daysRemainingOutOfRangeIsClamped() {
        let zero = plan { $0.daysRemainingInWeekIncludingToday = 0 }
        let one = plan { $0.daysRemainingInWeekIncludingToday = 1 }
        #expect(aerobic(zero) != nil)
        #expect(aerobic(zero) == aerobic(one))
    }

    @Test func availableTimeLimitsPlanAndSkipsStrength() throws {
        let p = plan { $0.availableMinutesToday = 20; $0.daysRemainingInWeekIncludingToday = 2 }
        let a = try #require(aerobic(p))
        #expect(a.minutesHigh <= 20)
        #expect(p.notices.contains(.limitedByAvailableTime))
        #expect(!p.items.contains { $0.kind == .strength })
    }

    @Test func obeseBMIGetsLowImpactEvenIfRunningPreferred() throws {
        let p = plan {
            $0.profile.heightCm = 170
            $0.profile.weightKg = 80 // 27.7: obese by Asian-Pacific cutoffs
            $0.bmiStandard = .asianPacific
            $0.preferredActivityIds = ["running"]
        }
        #expect(aerobic(p)?.activityId == "walking")
        #expect(p.notices.contains(.lowImpactSelected))
    }

    @Test func weeklyGoalReachedOmitsAerobic() {
        let p = plan { $0.week.moderateEquivalentMinutes = 160 }
        #expect(aerobic(p) == nil)
        #expect(p.notices.contains(.weeklyGoalReached))
    }

    @Test func olderAdultsGetBalance() {
        let p = plan { $0.profile.ageYears = 70 }
        #expect(p.items.contains { $0.kind == .balance && $0.activityId == "tai_chi" })
        // Tai chi's only catalog value is 3.0 MET, which is moderate by the MET band.
        #expect(p.items.contains { $0.kind == .balance && $0.met == 3.0 && $0.intensity == .moderate })
    }

    @Test func performanceAllowsVigorousWithHalvedMinutes() throws {
        let p = plan {
            $0.profile.activityLevel = .veryActive
            $0.profile.goal = .performance
            $0.preferredActivityIds = ["running"]
        }
        let a = try #require(aerobic(p))
        #expect(a.activityId == "running" && a.intensity == .vigorous)
        #expect(a.minutesLow == 10 && a.minutesHigh == 15) // 25 moderate-equivalent → 12.5 vigorous
    }

    @Test func strengthSkippedRightAfterStrengthDayWhenTimeRemains() {
        let p = plan { $0.week.didStrengthYesterday = true }
        #expect(!p.items.contains { $0.kind == .strength })
    }
}

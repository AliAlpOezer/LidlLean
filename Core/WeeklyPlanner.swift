import Foundation

struct PlanningDay: Identifiable {
    let date: Date
    let calories: Double
    let protein: Double
    let reviewed: Bool
    let restingEnergy: Double?
    let activeEnergy: Double?
    var id: Date { date }

    var expenditure: Double? {
        guard let restingEnergy, let activeEnergy,
              restingEnergy.isFinite, activeEnergy.isFinite,
              restingEnergy >= 0, activeEnergy >= 0 else { return nil }
        return restingEnergy + activeEnergy
    }

    var deficit: Double? {
        guard reviewed, calories.isFinite, calories >= 0 else { return nil }
        return expenditure.map { $0 - calories }
    }
}

struct WeeklyPlan {
    let days: [PlanningDay]
    let yesterday: PlanningDay?
    let weeklyTarget: Double
    let loggedThisWeek: Double
    let remainingAverage: Double?
    let remainingDays: Int
    let unreviewedDays: Int
    let proteinRemainingToday: Double
    let caloriesRemainingToday: Double
}

enum WeeklyPlanner {
    static func weekStart(containing date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let offset = (calendar.component(.weekday, from: day) + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: day)!
    }

    static func make(days: [PlanningDay], dailyCalories: Double, dailyProtein: Double,
                     now: Date, calendar: Calendar) -> WeeklyPlan {
        let today = calendar.startOfDay(for: now)
        let start = weekStart(containing: now, calendar: calendar)
        let elapsed = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        let byDate = Dictionary(days.map { (calendar.startOfDay(for: $0.date), $0) }, uniquingKeysWith: { _, new in new })
        let week = (0..<7).map { offset -> PlanningDay in
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            return byDate[date] ?? PlanningDay(date: date, calories: 0, protein: 0, reviewed: false, restingEnergy: nil, activeEnergy: nil)
        }
        let past = Array(week.prefix(elapsed))
        let missing = past.filter { !$0.reviewed }.count
        let target = dailyCalories.isFinite && dailyCalories > 0 ? dailyCalories * 7 : 0
        let remainingDays = 7 - elapsed
        let remaining = target - past.reduce(0) { $0 + $1.calories }
        let average = missing == 0 && target > 0 ? max(0, remaining / Double(remainingDays)) : nil
        let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: today)!
        let current = week[elapsed]
        return WeeklyPlan(days: week, yesterday: byDate[yesterdayDate], weeklyTarget: target,
                          loggedThisWeek: week.prefix(elapsed + 1).reduce(0) { $0 + $1.calories },
                          remainingAverage: average, remainingDays: remainingDays, unreviewedDays: missing,
                          proteinRemainingToday: max(0, dailyProtein - current.protein),
                          caloriesRemainingToday: max(0, dailyCalories - current.calories))
    }

    static func proteinPortion(proteinGap: Double, caloriesLeft: Double,
                               caloriesPer100g: Double, proteinPer100g: Double) -> Double? {
        guard [proteinGap, caloriesLeft, caloriesPer100g, proteinPer100g].allSatisfy({ $0.isFinite && $0 > 0 }),
              proteinPer100g <= 100 else { return nil }
        let grams = min(300, proteinGap / proteinPer100g * 100, caloriesLeft / caloriesPer100g * 100)
        let roundedDown = floor(grams / 5) * 5
        return roundedDown >= 20 ? roundedDown : nil
    }
}

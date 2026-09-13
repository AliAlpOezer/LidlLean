import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
}
func day(_ date: Date, kcal: Double = 2000, reviewed: Bool = true, resting: Double? = 1700, active: Double? = 500) -> PlanningDay {
    PlanningDay(date: date, calories: kcal, protein: 100, reviewed: reviewed, restingEnergy: resting, activeEnergy: active)
}
var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
    checks += 1
}

let monday = date(2026, 9, 14)
let tuesday = date(2026, 9, 15)
let wednesday = date(2026, 9, 16)
let plan = WeeklyPlanner.make(days: [day(monday, kcal: 2200), day(tuesday, kcal: 1800), day(wednesday, kcal: 500, reviewed: false)],
                              dailyCalories: 2000, dailyProtein: 150, now: wednesday, calendar: calendar)
expect(plan.weeklyTarget == 14000, "Weekly target must be seven daily targets")
expect(plan.remainingDays == 5 && plan.remainingAverage == 2000, "Remaining average includes the current day but excludes today's partial food")
expect(plan.loggedThisWeek == 4500, "Weekly consumed includes today's recorded food")
expect(plan.yesterday?.calories == 1800 && plan.yesterday?.deficit == 400, "Yesterday must use yesterday's food and both energy components")
expect(plan.proteinRemainingToday == 50, "Protein gap is independent from energy compensation")
expect(plan.caloriesRemainingToday == 1500, "Today's calorie allowance must reflect food already eaten")

let incomplete = WeeklyPlanner.make(days: [day(monday)], dailyCalories: 2000, dailyProtein: 150, now: wednesday, calendar: calendar)
expect(incomplete.remainingAverage == nil && incomplete.unreviewedDays == 1, "An absent day is incomplete, not fasting")
expect(day(monday, active: nil).deficit == nil, "Missing active calories cannot become zero")
expect(day(monday, resting: nil).deficit == nil, "Missing resting calories cannot become zero")
expect(day(monday, reviewed: false).deficit == nil, "Partial food logs cannot produce a deficit")

let rollover = WeeklyPlanner.make(days: [day(date(2026, 9, 13), kcal: 2300)], dailyCalories: 2000, dailyProtein: 150, now: monday, calendar: calendar)
expect(rollover.loggedThisWeek == 0 && rollover.yesterday?.calories == 2300, "Monday must reset the week and preserve Sunday comparison")
expect(rollover.remainingAverage == 2000 && rollover.remainingDays == 7, "A new week gets seven days")

let over = WeeklyPlanner.make(days: [day(monday, kcal: 16000)], dailyCalories: 2000, dailyProtein: 150, now: tuesday, calendar: calendar)
expect(over.remainingAverage == 0, "An exceeded weekly budget cannot yield negative calories")
expect(over.caloriesRemainingToday == 2000, "Overspending must not silently reduce today's target")

let dst = date(2026, 3, 29)
expect(WeeklyPlanner.weekStart(containing: dst, calendar: calendar) == calendar.startOfDay(for: date(2026, 3, 23)), "DST week begins on local Monday")
let dstPlan = WeeklyPlanner.make(days: [], dailyCalories: 2000, dailyProtein: 150, now: dst, calendar: calendar)
expect(dstPlan.remainingDays == 1 && dstPlan.days.count == 7, "DST must not change calendar day count")

let portion = WeeklyPlanner.proteinPortion(proteinGap: 30, caloriesLeft: 300, caloriesPer100g: 67, proteinPer100g: 12)
expect(portion == 250, "Protein suggestion should be 250 g for a 30 g gap at 12 g/100 g")
expect(WeeklyPlanner.proteinPortion(proteinGap: 30, caloriesLeft: 100, caloriesPer100g: 200, proteinPer100g: 20) == 50, "Portion must also fit calories")
expect(WeeklyPlanner.proteinPortion(proteinGap: 0, caloriesLeft: 300, caloriesPer100g: 67, proteinPer100g: 12) == nil, "No protein gap should produce no protein catch-up portion")
expect(WeeklyPlanner.proteinPortion(proteinGap: 30, caloriesLeft: .nan, caloriesPer100g: 67, proteinPer100g: 12) == nil, "Invalid numbers must not reach recommendations")
print("Passed \(checks) planning checks")

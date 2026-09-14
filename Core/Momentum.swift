import Foundation

struct MomentumDay: Equatable {
    let date: Date
    let mealCount: Int
    let protein: Double
    let reviewed: Bool
}

struct MomentumMission: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let complete: Bool
    let progress: Double
}

struct MomentumSnapshot: Equatable {
    let points: Int
    let streak: Int
    let level: Int
    let missions: [MomentumMission]

    var completedMissions: Int { missions.filter(\.complete).count }
    var levelProgress: Double { Double(points % MomentumEngine.pointsPerLevel) / Double(MomentumEngine.pointsPerLevel) }
}

enum MomentumEngine {
    static let pointsPerLevel = 50

    static func snapshot(for day: MomentumDay, history: [MomentumDay], proteinTarget: Double, calendar: Calendar) -> MomentumSnapshot {
        let validTarget = proteinTarget.isFinite && proteinTarget > 0 ? proteinTarget : 140
        let proteinPace = min(max(day.protein / (validTarget * 0.7), 0), 1)
        let missions = [
            MomentumMission(id: "log", title: "Log a real meal", detail: "Add one thing you ate", symbol: "checkmark", complete: day.mealCount > 0, progress: day.mealCount > 0 ? 1 : 0),
            MomentumMission(id: "protein", title: "Protein pace", detail: "Reach \(Int(validTarget * 0.7)) g today", symbol: "dumbbell.fill", complete: proteinPace >= 1, progress: proteinPace),
            MomentumMission(id: "review", title: "Close the day", detail: "Confirm your journal", symbol: "checkmark.seal.fill", complete: day.reviewed, progress: day.reviewed ? 1 : 0)
        ]
        let points = (missions[0].complete ? 10 : 0) + (missions[1].complete ? 25 : 0) + (missions[2].complete ? 15 : 0)
        return MomentumSnapshot(points: points, streak: streak(through: day.date, history: history, calendar: calendar), level: max(1, points / pointsPerLevel + 1), missions: missions)
    }

    private static func streak(through date: Date, history: [MomentumDay], calendar: Calendar) -> Int {
        let completeDays = Set(history.filter { $0.mealCount > 0 }.map { calendar.startOfDay(for: $0.date) })
        var cursor = calendar.startOfDay(for: date)
        var result = 0
        while completeDays.contains(cursor) {
            result += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return result
    }
}

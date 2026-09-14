import Foundation

struct TrainingExercise: Identifiable, Equatable {
    let name: String
    let prescription: String
    let cue: String
    var id: String { name }
}

struct TrainingSession: Identifiable, Equatable {
    let id: String
    let title: String
    let focus: String
    let durationMinutes: Int
    let exercises: [TrainingExercise]
}

enum TrainingProgram {
    static func session(for date: Date, startDate: Date, calendar: Calendar = .current) -> TrainingSession? {
        let day = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: date)).day ?? 0
        guard (0..<28).contains(day) else { return nil }
        switch day % 7 {
        case 0: return push
        case 1: return pull
        case 3: return skill
        case 4: return fullBody
        default: return nil
        }
    }

    static func dayID(for date: Date, startDate: Date, calendar: Calendar = .current) -> String {
        let day = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: date)).day ?? 0
        return "calisthenics-4w-\(max(day, 0))"
    }

    private static let push = TrainingSession(id: "push", title: "Push + Core", focus: "Chest · shoulders · trunk", durationMinutes: 48, exercises: [
        .init(name: "Wide push-ups", prescription: "4 × 12", cue: "Full range. Control the lowering."),
        .init(name: "Diamond push-ups", prescription: "3 × 10", cue: "Keep elbows close and ribs down."),
        .init(name: "Pike push-ups", prescription: "3 × 8", cue: "Hips high, head travels forward."),
        .init(name: "Hollow body hold", prescription: "4 × 25 sec", cue: "Keep lower back connected to the floor.")
    ])
    private static let pull = TrainingSession(id: "pull", title: "Pull + Grip", focus: "Back · biceps · posture", durationMinutes: 45, exercises: [
        .init(name: "Pull-ups or assisted pull-ups", prescription: "4 × quality reps", cue: "Start from a dead hang."),
        .init(name: "Inverted rows", prescription: "4 × 10", cue: "Pull chest toward the bar or table edge."),
        .init(name: "Scapular pulls", prescription: "3 × 10", cue: "Move shoulders first, keep arms straight."),
        .init(name: "Dead hang", prescription: "3 × 30 sec", cue: "Relax grip only as needed.")
    ])
    private static let skill = TrainingSession(id: "skill", title: "Skill + Mobility", focus: "Handstand · control · recovery", durationMinutes: 35, exercises: [
        .init(name: "Wrist and shoulder warm-up", prescription: "8 min", cue: "Move without forcing end range."),
        .init(name: "Wall handstand hold", prescription: "5 × 20 sec", cue: "Push tall through the shoulders."),
        .init(name: "Planche lean", prescription: "5 × 15 sec", cue: "Protract shoulders and keep elbows locked."),
        .init(name: "Thoracic rotations", prescription: "2 × 8 / side", cue: "Breathe slowly through each rep.")
    ])
    private static let fullBody = TrainingSession(id: "full", title: "Full body capacity", focus: "Push · pull · core", durationMinutes: 52, exercises: [
        .init(name: "Push-ups", prescription: "3 × 10", cue: "Leave one or two clean reps in reserve."),
        .init(name: "Chin-ups or rows", prescription: "3 × quality reps", cue: "Use the hardest safe variation."),
        .init(name: "Reverse lunges", prescription: "3 × 10 / side", cue: "Control the knee and keep the torso tall."),
        .init(name: "L-sit tuck hold", prescription: "5 × 15 sec", cue: "Press the floor away and breathe.")
    ])
}

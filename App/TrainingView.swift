import SwiftData
import SwiftUI

struct TrainingView: View {
    @Environment(\.modelContext) private var context
    @Query private var records: [WorkoutRecord]
    @AppStorage("training.programStart") private var startTimestamp = 0.0

    private var startDate: Date? { startTimestamp > 0 ? Date(timeIntervalSince1970: startTimestamp) : nil }
    private var session: TrainingSession? { startDate.flatMap { TrainingProgram.session(for: .now, startDate: $0) } }
    private var dayID: String? { startDate.map { TrainingProgram.dayID(for: .now, startDate: $0) } }
    private var completed: Bool { dayID.map { id in records.contains { $0.programDayID == id } } ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let session, let dayID { workout(session, dayID: dayID) }
                else if startDate == nil { startProgram }
                else { recoveryDay }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .accessibilityIdentifier("trainingScreen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TRAINING").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(AppTheme.success)
            Text("Build strength, not noise.").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink)
            Text("Your private 4-week calisthenics program, designed to fit around real life.").font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.muted)
        }
        .padding(.top, 16)
    }

    private var startProgram: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("4-WEEK CALISTHENICS", systemImage: "figure.strengthtraining.traditional")
                .font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(AppTheme.lime)
            Text("Start with today.").font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Four focused sessions each week: push, pull, skill, and full-body capacity. Recovery days are part of the program.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.72))
            Button("Start my program", systemImage: "arrow.right") { startTimestamp = Date.now.timeIntervalSince1970 }
                .buttonStyle(PrimaryActionStyle())
        }
        .padding(22)
        .foregroundStyle(.white)
        .background(LinearGradient(colors: [AppTheme.hero, AppTheme.primary], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func workout(_ session: TrainingSession, dayID: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY'S SESSION").font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(AppTheme.success)
                    Text(session.title).font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink)
                    Text("\(session.focus) · about \(session.durationMinutes) min").font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Image(systemName: completed ? "checkmark.circle.fill" : "figure.strengthtraining.traditional")
                    .font(.title).foregroundStyle(completed ? AppTheme.success : AppTheme.primary)
            }
            ForEach(session.exercises) { exercise in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "circle.fill").font(.system(size: 7)).foregroundStyle(AppTheme.lime).padding(.top, 6)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.name).font(.headline).foregroundStyle(AppTheme.ink)
                        Text(exercise.cue).font(.caption).foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    Text(exercise.prescription).font(.caption.weight(.bold)).foregroundStyle(AppTheme.primary).multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 4)
            }
            Button(completed ? "Session logged" : "Complete today's session", systemImage: completed ? "checkmark" : "checkmark.circle") {
                complete(dayID: dayID, duration: session.durationMinutes)
            }
            .buttonStyle(PrimaryActionStyle())
            .disabled(completed)
        }
        .padding(20)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(AppTheme.stroke) }
    }

    private var recoveryDay: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("RECOVERY DAY", systemImage: "heart.fill").font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(AppTheme.success)
                Text("Adaptation happens here.").font(.title2.bold()).foregroundStyle(AppTheme.ink)
                Text("Take a walk, work through gentle mobility, fuel yourself, and return ready for the next session.").font(.subheadline).foregroundStyle(AppTheme.muted)
            }
        }
    }

    private func complete(dayID: String, duration: Int) {
        guard !records.contains(where: { $0.programDayID == dayID }) else { return }
        context.insert(WorkoutRecord(programDayID: dayID, durationMinutes: duration))
        try? context.save()
    }
}

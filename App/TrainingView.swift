import SwiftData
import SwiftUI

struct TrainingView: View {
    @Environment(\.modelContext) private var context
    @Query private var records: [WorkoutRecord]
    @AppStorage("training.programStart") private var startTimestamp = 0.0
    @State private var checkedExercises = Set<String>()
    @State private var completionPresented = false
    @State private var pendingDayID: String?
    @State private var durationText = ""
    @State private var noteText = ""
    @State private var saveError: String?
    @State private var checklistDayID: String?

    private var calendar: Calendar { .current }
    private var startDate: Date? { startTimestamp > 0 ? Date(timeIntervalSince1970: startTimestamp) : nil }
    private var session: TrainingSession? { startDate.flatMap { TrainingProgram.session(for: .now, startDate: $0) } }
    private var dayID: String? { startDate.map { TrainingProgram.dayID(for: .now, startDate: $0) } }
    private var completed: Bool { dayID.map { id in records.contains { $0.programDayID == id } } ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if startDate == nil {
                    startProgram
                } else {
                    weekSchedule
                    if let session, let dayID { workout(session, dayID: dayID) }
                    else { recoveryDay }
                    recentHistory
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .accessibilityIdentifier("trainingScreen")
        .onChange(of: dayID) { _, newDayID in
            guard checklistDayID != newDayID else { return }
            checklistDayID = newDayID
            checkedExercises.removeAll()
        }
        .sheet(isPresented: $completionPresented) { completionSheet }
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

    private var weekSchedule: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionEyebrow(title: "This week")
                    Spacer()
                    Text("4-week plan").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.muted)
                }
                HStack(spacing: 6) {
                    ForEach(currentWeek) { item in
                        VStack(spacing: 6) {
                            Text(item.date.formatted(.dateTime.weekday(.narrow)))
                                .font(.caption2.weight(.bold)).foregroundStyle(AppTheme.muted)
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : item.inProgram ? (item.session == nil ? "heart.circle" : "circle") : "minus.circle")
                                .font(.headline)
                                .foregroundStyle(item.isCompleted ? AppTheme.success : item.inProgram ? (item.session == nil ? AppTheme.success : AppTheme.primary) : AppTheme.muted)
                            Text(item.shortTitle)
                                .font(.caption2.weight(.semibold)).foregroundStyle(AppTheme.ink).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .padding(.vertical, 5)
                        .background(item.isToday ? AppTheme.elevated : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(item.accessibilityLabel)
                    }
                }
                Text("The schedule is a guide. Only a confirmed save counts in history.")
                    .font(.caption).foregroundStyle(AppTheme.muted)
            }
        }
    }

    private struct WeekScheduleItem: Identifiable {
        let date: Date
        let session: TrainingSession?
        let dayID: String?
        let isCompleted: Bool
        let isToday: Bool
        let inProgram: Bool

        var id: Date { date }
        var shortTitle: String {
            guard inProgram else { return "Outside" }
            guard let session else { return "Rest" }
            return session.title.split(separator: " ").first.map(String.init) ?? "Session"
        }
        var accessibilityLabel: String {
            let title = inProgram ? (session?.title ?? "Recovery day") : "Outside this plan"
            return "\(date.formatted(.dateTime.weekday(.wide))), \(title)\(isCompleted ? ", completed" : "")"
        }
    }

    private var currentWeek: [WeekScheduleItem] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            guard let startDate else {
                return WeekScheduleItem(date: date, session: nil, dayID: nil, isCompleted: false,
                                        isToday: calendar.isDateInToday(date), inProgram: false)
            }
            let day = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: date)).day ?? 0
            let inProgram = (0..<28).contains(day)
            let itemSession = inProgram ? TrainingProgram.session(for: date, startDate: startDate, calendar: calendar) : nil
            let itemID = inProgram ? TrainingProgram.dayID(for: date, startDate: startDate, calendar: calendar) : nil
            let isCompleted = itemSession != nil && itemID.map { id in records.contains { $0.programDayID == id } } == true
            return WeekScheduleItem(date: date, session: itemSession, dayID: itemID, isCompleted: isCompleted,
                                    isToday: calendar.isDateInToday(date), inProgram: inProgram)
        }
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
            HStack {
                SectionEyebrow(title: "Session checklist")
                Spacer()
                Text("\(checkedExercises.count)/\(session.exercises.count) checked")
                    .font(.caption.weight(.semibold)).foregroundStyle(AppTheme.muted)
            }
            ForEach(session.exercises) { exercise in
                Button {
                    if checkedExercises.contains(exercise.id) { checkedExercises.remove(exercise.id) }
                    else { checkedExercises.insert(exercise.id) }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: checkedExercises.contains(exercise.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title3).foregroundStyle(checkedExercises.contains(exercise.id) ? AppTheme.success : AppTheme.muted)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(exercise.name).font(.headline).foregroundStyle(AppTheme.ink)
                            Text(exercise.cue).font(.caption).foregroundStyle(AppTheme.muted)
                        }
                        Spacer()
                        Text(exercise.prescription).font(.caption.weight(.bold)).foregroundStyle(AppTheme.primary).multilineTextAlignment(.trailing)
                    }
                }
                .buttonStyle(.plain)
                .disabled(completed)
                .accessibilityIdentifier("exerciseCheck-\(exercise.id)")
                .frame(minHeight: 44, alignment: .center)
                .padding(.vertical, 4)
            }
            Button(completed ? "Session logged" : "Review and save session", systemImage: completed ? "checkmark" : "checkmark.circle") {
                if pendingDayID != dayID {
                    pendingDayID = dayID
                    durationText = ""
                    noteText = ""
                }
                saveError = nil
                completionPresented = true
            }
            .buttonStyle(PrimaryActionStyle())
            .disabled(completed)
            .accessibilityIdentifier("trainingComplete")
        }
        .padding(20)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 28).stroke(AppTheme.stroke) }
    }

    private var completionSheet: some View {
        NavigationStack {
            Form {
                Section("Actual session") {
                    TextField("Minutes completed", text: $durationText)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("workoutDuration")
                    Text("Enter what you actually completed. The plan's estimate is not saved automatically.")
                        .font(.caption).foregroundStyle(AppTheme.muted)
                }
                Section("Reflection (optional)") {
                    TextField("How did it feel?", text: $noteText, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("workoutNote")
                }
                if let saveError { Section { Text(saveError).foregroundStyle(AppTheme.warning) } }
            }
            .navigationTitle("Save workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { completionPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveWorkout() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("saveWorkout")
                }
            }
        }
    }

    private var recentHistory: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(title: "Recent history")
                let recent = records.sorted { $0.completedAt > $1.completedAt }.prefix(5)
                if recent.isEmpty {
                    Text("Confirmed workouts will appear here.").font(.subheadline).foregroundStyle(AppTheme.muted)
                } else {
                    ForEach(Array(recent)) { record in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(record.completedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(record.durationMinutes) min").font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.success)
                            }
                            if !record.note.isEmpty { Text(record.note).font(.caption).foregroundStyle(AppTheme.muted) }
                        }
                        if record.id != recent.last?.id { Divider() }
                    }
                }
            }
        }
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

    private func saveWorkout() {
        guard pendingDayID == dayID else {
            saveError = "This session is no longer today. Reopen Training to review the current session before saving."
            return
        }
        guard let pendingDayID, let duration = Int(durationText.trimmingCharacters(in: .whitespacesAndNewlines)), duration > 0, duration <= 600 else {
            saveError = "Enter the actual session duration in minutes."
            return
        }
        guard !records.contains(where: { $0.programDayID == pendingDayID }) else {
            completionPresented = false
            return
        }
        let record = WorkoutRecord(programDayID: pendingDayID, durationMinutes: duration,
                                   note: noteText.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(record)
        do {
            try context.save()
            completionPresented = false
            checkedExercises.removeAll()
            self.pendingDayID = nil
        } catch {
            context.rollback()
            saveError = "Could not save workout: \(error.localizedDescription)"
        }
    }
}

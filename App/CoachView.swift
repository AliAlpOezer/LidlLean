import SwiftData
import SwiftUI

struct CoachView: View {
    @Query(sort: \MealEntry.consumedAt, order: .reverse) private var entries: [MealEntry]
    @Query private var goals: [UserGoal]
    @State private var consent = false
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 18) { Text("Coach\nwithout the noise.").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink); SurfaceCard { VStack(alignment: .leading, spacing: 12) { Text("AI IS OPTIONAL").font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(AppTheme.lime); Text("When enabled, the coach receives only today's macro totals and targets. No food names, barcodes, Apple Health data, identity, or location.").foregroundStyle(AppTheme.ink); Toggle("I consent to this limited request", isOn: $consent).tint(AppTheme.lime); Button("Configure OpenRouter key") {}.buttonStyle(.borderedProminent).tint(AppTheme.lime).foregroundStyle(AppTheme.canvas).disabled(!consent) } }; Text("The initial interface is intentionally gated until a personal OpenRouter key is added to Keychain. This prevents a secret from being exposed in a sideloaded IPA.").font(.footnote).foregroundStyle(AppTheme.muted) }.padding(16) }.background(AppTheme.canvas.ignoresSafeArea()).navigationTitle("AI coach").navigationBarTitleDisplayMode(.inline) } }

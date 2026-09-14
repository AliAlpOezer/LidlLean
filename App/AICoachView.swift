import SwiftUI

struct AICoachView: View {
    @Environment(\.dismiss) private var dismiss
    let snapshot: AICoachSnapshot
    @State private var apiKey = ""
    @State private var consent = false
    @State private var response: AICoachResponse?
    @State private var errorMessage: String?
    @State private var loading = false
    @State private var keyStored = false
    @State private var showingKey = false
    private let client = OpenRouterClient()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    intro
                    keyCard
                    previewCard
                    consentCard
                    if let response { responseCard(response) }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(AppTheme.canvas.ignoresSafeArea())
            .navigationTitle("AI coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { loadKey() }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("A second opinion,\nnot a second calculator.")
                .font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink)
            Text("Your targets and totals stay deterministic. AI only interprets the aggregate shown below.")
                .font(.subheadline).foregroundStyle(AppTheme.muted)
        }
    }

    private var keyCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(title: "OpenRouter key")
                Group {
                    if showingKey { TextField("sk-or-v1-...", text: $apiKey) }
                    else { SecureField("sk-or-v1-...", text: $apiKey) }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospaced())
                .padding(12)
                .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("openRouterKey")
                Toggle("Show key", isOn: $showingKey)
                HStack {
                    Link("Create an OpenRouter key", destination: URL(string: "https://openrouter.ai/settings/keys")!)
                    Spacer()
                    if keyStored { Button("Remove", role: .destructive) { removeKey() } }
                }
                .font(.subheadline.weight(.semibold))
                Text("Stored only in this iPhone's Keychain. It is never placed in the repository or prompt.")
                    .font(.caption).foregroundStyle(AppTheme.muted)
            }
        }
    }

    private var previewCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(title: "Exact request preview")
                DisclosureGroup("System instruction") {
                    Text(AICoachPrompt.system).font(.caption).foregroundStyle(AppTheme.muted).textSelection(.enabled)
                        .padding(.top, 8)
                }
                DisclosureGroup("Aggregate data") {
                    Text(AICoachPrompt.userMessage(for: snapshot)).font(.caption.monospaced()).foregroundStyle(AppTheme.muted)
                        .textSelection(.enabled).padding(.top, 8)
                }
                Text("No food names, barcodes, raw Health samples, dates, location, or identifiers are included.")
                    .font(.caption.weight(.semibold)).foregroundStyle(AppTheme.success)
            }
        }
    }

    private var consentCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("I approve sending exactly this preview to OpenRouter and its selected model provider.", isOn: $consent)
                    .tint(AppTheme.primary)
                Text("The request denies providers that collect data. Free-model availability and provider retention policies can change.")
                    .font(.caption).foregroundStyle(AppTheme.muted)
                if let errorMessage { Text(errorMessage).font(.footnote.weight(.semibold)).foregroundStyle(.red) }
                Button {
                    Task { await generate() }
                } label: {
                    if loading { ProgressView().tint(.white) }
                    else { Label("Generate weekly insight", systemImage: "sparkles") }
                }
                .buttonStyle(PrimaryActionStyle())
                .disabled(!consent || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 || loading)
                .opacity(!consent || loading ? 0.55 : 1)
            }
        }
    }

    private func responseCard(_ response: AICoachResponse) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(title: "Weekly insight")
                Text(response.text).foregroundStyle(AppTheme.ink).textSelection(.enabled)
                Label(response.model, systemImage: "cpu")
                    .font(.caption).foregroundStyle(AppTheme.muted)
            }
        }
    }

    private func loadKey() {
        do {
            apiKey = try KeychainStore.readAPIKey() ?? ""
            keyStored = !apiKey.isEmpty
        } catch { errorMessage = error.localizedDescription }
    }

    private func removeKey() {
        do {
            try KeychainStore.deleteAPIKey()
            apiKey = ""
            keyStored = false
        } catch { errorMessage = error.localizedDescription }
    }

    private func generate() async {
        guard consent, !loading else { return }
        loading = true
        errorMessage = nil
        defer { loading = false }
        do {
            let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            try KeychainStore.saveAPIKey(trimmedKey)
            keyStored = true
            response = try await client.insight(for: snapshot, apiKey: trimmedKey)
        } catch { errorMessage = error.localizedDescription }
    }
}

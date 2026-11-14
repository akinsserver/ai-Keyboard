import SwiftUI

/// Settings: tone, custom approach, reply length, AI provider, Gemini key.
struct SettingsView: View {

    @StateObject private var settings = SettingsStore.shared
    @State private var apiKeyDraft: String = ""
    @State private var testMessage: String = ""
    @State private var isTestingKey = false

    var body: some View {
        Form {
            Section("Reply style") {
                Picker("Tone", selection: $settings.tone) {
                    ForEach(Tone.allCases) { tone in
                        Text(tone.displayName).tag(tone)
                    }
                }
                if settings.tone == .custom {
                    TextField("Custom approach, e.g. be smooth and confident, ask about her trip", text: $settings.customApproach, axis: .vertical)
                        .lineLimit(3...6)
                }
            }

            Section("Reply length") {
                Stepper("Minimum length: \(settings.minLength) characters", value: $settings.minLength, in: 1...200)
                Stepper("Maximum length: \(settings.maxLength) characters", value: $settings.maxLength, in: 10...500)
                if settings.minLength >= settings.maxLength {
                    Text("Minimum must be smaller than maximum.")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section("AI provider") {
                Picker("Provider", selection: $settings.provider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                Text("Apple Foundation Models needs iPhone 15 Pro or newer with Apple Intelligence. This phone (iPhone 14 Pro) cannot use it, so Gemini is the main provider here. Auto tries on-device first and falls back to Gemini.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Gemini API key") {
                SecureField("Paste your Gemini API key", text: $apiKeyDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                HStack {
                    Button("Save key") {
                        settings.apiKey = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        testMessage = settings.hasAPIKey ? "Key saved." : "Key cleared."
                    }
                    .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !settings.hasAPIKey)
                    Spacer()
                    Button("Test key") {
                        testKey()
                    }
                    .disabled(!settings.hasAPIKey || isTestingKey)
                }
                if isTestingKey {
                    ProgressView("Testing key…")
                }
                if !testMessage.isEmpty {
                    Text(testMessage).font(.footnote)
                }
                if let aiStudioURL = URL(string: "https://aistudio.google.com") {
                    Link("Get a free key at Google AI Studio", destination: aiStudioURL)
                }
                Text("Free tier, no card needed. A Gemini Pro subscription is NOT an API key — you still need a key from AI Studio. The key is stored in the App Group shared settings in v1; the README notes the plan to move it to the shared Keychain.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Gemini model") {
                TextField("Model, e.g. gemini-2.5-flash", text: $settings.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Privacy") {
                Text("No keystroke logging. No analytics. Screenshots are read on-device. Only the extracted chat text is sent to the AI, only when you tap Generate.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            apiKeyDraft = settings.apiKey
        }
    }

    private func testKey() {
        isTestingKey = true
        testMessage = ""
        Task {
            do {
                let client = GeminiClient(settings: settings)
                let reply = try await client.generate(prompt: "Reply with exactly this word: OK")
                await MainActor.run {
                    isTestingKey = false
                    testMessage = reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Key works, but Gemini returned an empty reply."
                        : "Key works. Gemini replied."
                }
            } catch {
                await MainActor.run {
                    isTestingKey = false
                    testMessage = error.localizedDescription
                }
            }
        }
    }
}

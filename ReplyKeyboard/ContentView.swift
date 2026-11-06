import Photos
import SwiftUI
import ReplyKit

/// Setup checklist for the container app.
///
/// Note: iOS has no public API that tells the container app whether its
/// custom keyboard is enabled, or whether Allow Full Access is on. Those
/// two rows are manual steps the user ticks off by following the guide.
/// The rows the app CAN check (API key, Photos permission) are live.
struct ContentView: View {

    @StateObject private var settings = SettingsStore.shared
    @State private var photosStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        NavigationStack {
            List {
                Section("What this app does") {
                    Text("Reply Keyboard reads your latest chat screenshot, suggests 3 replies, and lets you tap one to insert it while typing. The screenshot text is read on your phone. Only the chat text — never the photo — is sent to the AI, and only when you tap Generate.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Setup checklist") {
                    checklistRow(
                        title: "Add the keyboard",
                        detail: "Settings > General > Keyboard > Keyboards > Add New Keyboard > Reply Keyboard",
                        done: nil
                    )
                    checklistRow(
                        title: "Turn on Allow Full Access",
                        detail: "Settings > General > Keyboard > Keyboards > Reply Keyboard > Allow Full Access. The keyboard needs this for network and Photos. Without it, it still works as a plain keyboard, but AI suggestions are off.",
                        done: nil
                    )
                    checklistRow(
                        title: "Allow Photos access",
                        detail: photosStatus == .authorized || photosStatus == .limited
                            ? "Photos access is on."
                            : "Tap to allow Photos access so the keyboard can read your latest screenshot.",
                        done: photosStatus == .authorized || photosStatus == .limited,
                        action: requestPhotosAccess
                    )
                    checklistRow(
                        title: "Paste your Gemini API key",
                        detail: settings.hasAPIKey
                            ? "API key saved. Get a free key at Google AI Studio (aistudio.google.com). Your Gemini Pro subscription is not an API key."
                            : "No key yet. Get a free key at Google AI Studio (aistudio.google.com) — no card needed — and paste it in Settings.",
                        done: settings.hasAPIKey ? true : false
                    )
                    checklistRow(
                        title: "Try it in the app first",
                        detail: "Use Test with a Screenshot below. It runs the same OCR and generation as the keyboard, so you can check it works before typing in another app.",
                        done: nil
                    )
                }

                Section {
                    NavigationLink("Settings — tone, provider, API key") {
                        SettingsView()
                    }
                    NavigationLink("Test with a Screenshot") {
                        ScreenshotTestView()
                    }
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section("Privacy") {
                    Text("No keystroke logging. No analytics. Screenshots are read on-device with Vision. Only the extracted chat text is sent to Gemini, only when you tap Generate. The API key is stored in the shared App Group settings in v1 — see the README for the Keychain TODO.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Reply Keyboard")
            .onAppear {
                photosStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            }
        }
    }

    private func requestPhotosAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                photosStatus = status
            }
        }
    }

    @ViewBuilder
    private func checklistRow(title: String, detail: String, done: Bool?, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: done == true ? "checkmark.circle.fill" : done == false ? "circle" : "number.circle")
                    .foregroundStyle(done == true ? .green : .secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

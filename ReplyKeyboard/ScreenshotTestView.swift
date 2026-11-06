import Photos
import SwiftUI
import ReplyKit

/// Tests the full flow inside the container app, without the keyboard:
/// import the latest screenshot, run on-device OCR, generate 3 suggestions.
struct ScreenshotTestView: View {

    @StateObject private var settings = SettingsStore.shared
    @State private var screenshot: UIImage?
    @State private var transcript: String = ""
    @State private var suggestions: [String] = []
    @State private var statusMessage: String = "Take a screenshot of a chat first, then tap below."
    @State private var isWorking = false

    private let screenshotService = ScreenshotService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Import latest screenshot") {
                    runTest()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking)

                if isWorking {
                    ProgressView("Reading screenshot and generating replies…")
                }

                if let screenshot {
                    Image(uiImage: screenshot)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if !transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Text read from the screenshot").font(.headline)
                        Text(transcript)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }

                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggestions").font(.headline)
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                UIPasteboard.general.string = suggestion
                                statusMessage = "Copied to clipboard: \(suggestion)"
                            } label: {
                                Text(suggestion)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                        Text("Tap a suggestion to copy it. In the keyboard, tapping inserts it at the cursor instead.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Test with a Screenshot")
    }

    private func runTest() {
        isWorking = true
        suggestions = []
        transcript = ""
        screenshot = nil
        statusMessage = "Reading your latest screenshot…"

        Task {
            do {
                let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                if status != .authorized && status != .limited {
                    let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                    guard newStatus == .authorized || newStatus == .limited else {
                        throw ScreenshotError.photosDenied
                    }
                }
                guard let asset = screenshotService.latestScreenshotAsset() else {
                    throw ScreenshotError.noScreenshot
                }
                let image = try await screenshotService.image(for: asset)
                let text = try screenshotService.recognizeText(in: image)
                await MainActor.run {
                    screenshot = image
                    transcript = text
                    statusMessage = "Text read. Generating 3 replies…"
                }
                let engine = SuggestionEngine(settings: settings)
                let generated = try await engine.generateSuggestions(for: text)
                await MainActor.run {
                    suggestions = generated
                    statusMessage = "Done. Tap a suggestion to copy it."
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = error.localizedDescription
                    isWorking = false
                }
            }
        }
    }
}

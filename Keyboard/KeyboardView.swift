import Photos
import SwiftUI
import ReplyKit

/// View model for the keyboard. Owns typing, the screenshot flow and
/// suggestion state. OCR and network run on background tasks; only the
/// published results touch the main thread.
final class KeyboardViewModel: ObservableObject {

    weak var controller: UIInputViewController?

    @Published var suggestions: [String] = []
    @Published var statusMessage: String = ""
    @Published var isWorking = false
    @Published var hasFullAccess = false
    @Published var isShifted = false
    @Published var isNumeric = false

    @Published var selectedTone: Tone {
        didSet { SettingsStore.shared.tone = selectedTone }
    }

    private let settings = SettingsStore.shared
    private let screenshotService = ScreenshotService()

    init() {
        self.selectedTone = SettingsStore.shared.tone
    }

    // MARK: - Typing

    func insert(_ text: String) {
        controller?.textDocumentProxy.insertText(text)
    }

    func insertLetter(_ letter: String) {
        let text = isShifted ? letter.uppercased() : letter.lowercased()
        insert(text)
        if isShifted { isShifted = false }
    }

    func deleteBackward() {
        controller?.textDocumentProxy.deleteBackward()
    }

    func advanceToNextInputMode() {
        controller?.advanceToNextInputMode()
    }

    // MARK: - Screenshot + suggestions

    /// Reads the latest screenshot, OCRs it on-device, and generates
    /// 3 reply suggestions. Only the extracted text is sent to the AI.
    func generateFromLatestScreenshot() {
        guard hasFullAccess else {
            statusMessage = "AI needs Allow Full Access. Turn it on in Settings > General > Keyboard > Keyboards > Reply Keyboard. Typing still works without it."
            return
        }
        guard !isWorking else { return }
        isWorking = true
        suggestions = []
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
                let transcript = try screenshotService.recognizeText(in: image)
                await MainActor.run {
                    statusMessage = "Generating 3 replies…"
                }
                let engine = SuggestionEngine(settings: settings)
                let generated = try await engine.generateSuggestions(for: transcript)
                await MainActor.run {
                    suggestions = generated
                    statusMessage = "Tap a suggestion to insert it."
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

/// The keyboard UI: top bar (tones + Screenshot), suggestions row,
/// and a full QWERTY layout with shift, delete, space, return,
/// numbers toggle and the globe key.
struct KeyboardView: View {

    @ObservedObject var viewModel: KeyboardViewModel

    private let letterRows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ]
    private let numberRows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
        [".", ",", "?", "!", "'"]
    ]

    var body: some View {
        VStack(spacing: 6) {
            topBar
            suggestionsRow
            statusLine
            keys
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Tone.allCases) { tone in
                        Button(tone.displayName) {
                            viewModel.selectedTone = tone
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(viewModel.selectedTone == tone ? Color.blue : Color(.systemGray5))
                        .foregroundStyle(viewModel.selectedTone == tone ? .white : .primary)
                        .clipShape(Capsule())
                    }
                }
            }
            Button {
                viewModel.generateFromLatestScreenshot()
            } label: {
                Label("Screenshot", systemImage: "camera.viewfinder")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .disabled(viewModel.isWorking || !viewModel.hasFullAccess)
        }
    }

    // MARK: - Suggestions

    private var suggestionsRow: some View {
        Group {
            if viewModel.isWorking {
                ProgressView("Reading screenshot…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if !viewModel.suggestions.isEmpty {
                VStack(spacing: 6) {
                    ForEach(viewModel.suggestions, id: \.self) { suggestion in
                        Button {
                            viewModel.insert(suggestion + " ")
                        } label: {
                            Text(suggestion)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("Take a screenshot of a chat, switch to this keyboard, then tap Screenshot.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var statusLine: some View {
        Group {
            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            if !viewModel.hasFullAccess {
                Text("Allow Full Access is off, so AI suggestions are unavailable. This keyboard still types normally.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Keys

    private var keys: some View {
        VStack(spacing: 6) {
            ForEach(currentRows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
            HStack(spacing: 4) {
                Button {
                    viewModel.isShifted.toggle()
                } label: {
                    Image(systemName: viewModel.isShifted ? "shift.fill" : "shift")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray4))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .disabled(viewModel.isNumeric)
                Button("123") {
                    viewModel.isNumeric.toggle()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(.systemGray4))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                Button("space") {
                    viewModel.insert(" ")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                Button("return") {
                    viewModel.insert("\n")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                Button {
                    viewModel.deleteBackward()
                } label: {
                    Image(systemName: "delete.left")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray4))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            HStack(spacing: 4) {
                Button {
                    viewModel.advanceToNextInputMode()
                } label: {
                    Image(systemName: "globe")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray4))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Text("Reply Keyboard")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private var currentRows: [[String]] {
        viewModel.isNumeric ? numberRows : letterRows
    }

    private func keyButton(_ key: String) -> some View {
        Button(viewModel.isShifted && !viewModel.isNumeric ? key.uppercased() : key) {
            viewModel.insertLetter(key)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

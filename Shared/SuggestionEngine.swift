import Foundation

/// Anything that can turn a prompt into raw reply text.
public protocol SuggestionClient {
    func generate(prompt: String) async throws -> String
}

public enum SuggestionError: Error, LocalizedError {
    case missingAPIKey
    case foundationModelsUnavailable
    case noSuggestions

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No Gemini API key saved. Add your free key in the Reply Keyboard app settings."
        case .foundationModelsUnavailable:
            return "Apple Foundation Models is not available on this phone. It needs iPhone 15 Pro or newer with Apple Intelligence. Switch the provider to Gemini."
        case .noSuggestions:
            return "The AI returned no suggestions. Please try again."
        }
    }
}

/// Builds the suggestion prompt from the OCR transcript and parses the
/// model's reply into exactly three suggestions.
public struct SuggestionEngine {

    private let settings: SettingsStore
    private let gemini: GeminiClient
    private let foundationModels: FoundationModelsClient

    public init(
        settings: SettingsStore = .shared,
        gemini: GeminiClient? = nil,
        foundationModels: FoundationModelsClient = FoundationModelsClient()
    ) {
        self.settings = settings
        self.gemini = gemini ?? GeminiClient(settings: settings)
        self.foundationModels = foundationModels
    }

    /// Generates three reply suggestions for an OCR transcript.
    public func generateSuggestions(for transcript: String) async throws -> [String] {
        let prompt = Self.buildPrompt(
            transcript: transcript,
            tone: settings.tone,
            customApproach: settings.customApproach,
            minLength: settings.minLength,
            maxLength: settings.maxLength
        )

        let raw: String
        switch settings.provider {
        case .gemini:
            guard settings.hasAPIKey else { throw SuggestionError.missingAPIKey }
            raw = try await gemini.generate(prompt: prompt)
        case .foundationModels:
            guard FoundationModelsClient.isAvailable else {
                throw SuggestionError.foundationModelsUnavailable
            }
            raw = try await foundationModels.generate(prompt: prompt)
        case .auto:
            if FoundationModelsClient.isAvailable {
                raw = try await foundationModels.generate(prompt: prompt)
            } else {
                guard settings.hasAPIKey else { throw SuggestionError.missingAPIKey }
                raw = try await gemini.generate(prompt: prompt)
            }
        }

        let suggestions = Self.parseSuggestions(from: raw)
        guard !suggestions.isEmpty else { throw SuggestionError.noSuggestions }
        return suggestions
    }

    /// Builds the prompt sent to the AI. Only the extracted chat TEXT is
    /// sent — never the screenshot image.
    public static func buildPrompt(
        transcript: String,
        tone: Tone,
        customApproach: String,
        minLength: Int,
        maxLength: Int
    ) -> String {
        var toneLine = tone.promptInstruction
        if tone == .custom, !customApproach.trimmingCharacters(in: .whitespaces).isEmpty {
            toneLine += " Custom approach: \(customApproach)"
        }
        return """
        You are helping someone reply to a chat message. Below is the text \
        read from a screenshot of their chat. The last message in the chat is \
        the one they need to reply to.

        \(toneLine)
        Each reply must be between \(minLength) and \(maxLength) characters long.
        Write as the person replying, in first person, in plain everyday language.
        Do not explain anything. Do not add quotes around the replies.
        Return exactly 3 different replies, as a JSON array of 3 strings, for example:
        ["first reply", "second reply", "third reply"]

        Chat transcript:
        \(transcript)
        """
    }

    /// Parses model output into up to three suggestions. Accepts a JSON
    /// array of strings, or falls back to numbered / line-separated replies.
    /// Markdown code fences are stripped first.
    public static func parseSuggestions(from raw: String) -> [String] {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let data = text.data(using: .utf8),
           let json = try? JSONDecoder().decode([String].self, from: data) {
            return clean(json)
        }

        var lines: [String] = []
        for line in text.components(separatedBy: .newlines) {
            var candidate = line.trimmingCharacters(in: .whitespaces)
            if candidate.isEmpty { continue }
            // Strip "1. ", "1) ", "- " style prefixes.
            if let range = candidate.range(of: #"^\d+[.\)]\s+"#, options: .regularExpression) {
                candidate = String(candidate[range.upperBound...])
            } else if candidate.hasPrefix("- ") {
                candidate = String(candidate.dropFirst(2))
            }
            candidate = candidate.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if !candidate.isEmpty {
                lines.append(candidate)
            }
        }
        return clean(lines)
    }

    private static func clean(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            result.append(trimmed)
            if result.count == 3 { break }
        }
        return result
    }
}

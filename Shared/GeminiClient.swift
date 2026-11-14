import Foundation

/// Errors from the Gemini cloud API.
public enum GeminiError: Error, LocalizedError {
    case missingAPIKey
    case unauthorized
    case rateLimited
    case serverError(statusCode: Int)
    case network(Error)
    case invalidResponse
    case noText

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No Gemini API key saved. Add your free key in the Reply Keyboard app settings."
        case .unauthorized:
            return "Gemini rejected the API key (401). Check the key you pasted in Settings."
        case .rateLimited:
            return "Gemini rate limit reached (429). Wait a minute and try again."
        case .serverError(let statusCode):
            return "Gemini returned an error (HTTP \(statusCode)). Please try again."
        case .network:
            return "No network connection. Check Wi-Fi or mobile data and try again."
        case .invalidResponse:
            return "Gemini returned a reply I could not understand. Please try again."
        case .noText:
            return "Gemini returned an empty reply. Please try again."
        }
    }
}

/// Minimal client for the Gemini `generateContent` REST API.
///
/// The API key comes from SettingsStore (entered in the container app).
/// A Gemini API key from Google AI Studio is NOT the same thing as a
/// Gemini Pro subscription — the subscription does not provide an API key.
public struct GeminiClient: SuggestionClient {

    private let settings: SettingsStore
    private let session: URLSession

    public init(settings: SettingsStore = .shared, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    public func generate(prompt: String) async throws -> String {
        guard settings.hasAPIKey else { throw GeminiError.missingAPIKey }
        let model = settings.model
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw GeminiError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(settings.apiKey, forHTTPHeaderField: "x-goog-api-key")

        let body = GeminiRequest(
            contents: [GeminiContent(parts: [GeminiPart(text: prompt)])],
            generationConfig: GeminiGenerationConfig(temperature: 0.9, maxOutputTokens: 400)
        )
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GeminiError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw GeminiError.unauthorized
        case 429:
            throw GeminiError.rateLimited
        default:
            throw GeminiError.serverError(statusCode: httpResponse.statusCode)
        }

        guard let decoded = try? JSONDecoder().decode(GeminiResponse.self, from: data),
              let text = decoded.candidates?.first?.content.parts.first?.text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiError.noText
        }
        return text
    }
}

// MARK: - Request / response models

private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String
}

private struct GeminiGenerationConfig: Encodable {
    let temperature: Double
    let maxOutputTokens: Int
}

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]?
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContent
}

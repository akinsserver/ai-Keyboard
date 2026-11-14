import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Errors from Apple Foundation Models (on-device Apple Intelligence).
public enum FoundationModelsError: Error, LocalizedError {
    case unavailable
    case generationFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Foundation Models is not available on this phone. It needs iPhone 15 Pro or newer with Apple Intelligence turned on."
        case .generationFailed:
            return "Apple Foundation Models could not generate a reply. Please try again or switch to Gemini."
        }
    }
}

/// Client for Apple Foundation Models (iOS 26+, iPhone 15 Pro or newer).
///
/// This file compiles under the iOS 18 deployment target because every
/// Foundation Models API use is gated with `#available(iOS 26.0, *)`.
/// On older phones `isAvailable` is simply false and the caller falls
/// back to Gemini. Do NOT raise the package deployment target to iOS 26.
public struct FoundationModelsClient: SuggestionClient {

    public init() {}

    /// True only on iOS 26+ when the on-device model is ready.
    public static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        } else {
            return false
        }
        #else
        return false
        #endif
    }

    public func generate(prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession()
                let response = try await session.respond(to: prompt)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { throw FoundationModelsError.unavailable }
                return text
            } catch let error as FoundationModelsError {
                throw error
            } catch {
                throw FoundationModelsError.generationFailed(error)
            }
        } else {
            throw FoundationModelsError.unavailable
        }
        #else
        throw FoundationModelsError.unavailable
        #endif
    }
}

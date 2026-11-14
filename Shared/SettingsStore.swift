import Foundation

/// Which AI backend generates the reply suggestions.
public enum AIProvider: String, CaseIterable, Identifiable, Codable {
    /// Always use the Gemini cloud API.
    case gemini = "gemini"
    /// Always use Apple Foundation Models (iOS 26+, newer phones only).
    case foundationModels = "foundation_models"
    /// Try Apple Foundation Models when available, otherwise use Gemini.
    case auto = "auto"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gemini: return "Gemini"
        case .foundationModels: return "Apple Foundation Models"
        case .auto: return "Auto (on-device first, then Gemini)"
        }
    }
}

/// Shared settings for the container app and the keyboard extension.
///
/// Storage: the App Group shared UserDefaults (suite
/// `group.com.akinsserver.replykeyboard`).
///
/// V1 PERSONAL-USE TRADEOFF: the Gemini API key is stored here in plain
/// text in shared UserDefaults so the keyboard extension can read it
/// without a login flow. That is acceptable for a personal app on your own
/// phone, but it is NOT how a shipped App Store app should store a secret.
/// TODO: move the API key to the shared Keychain (kSecAttrAccessGroup with
/// the App Group) and delete it from UserDefaults.
public final class SettingsStore: ObservableObject {

    public static let appGroupID = "group.com.akinsserver.replykeyboard"

    public static let shared = SettingsStore()

    private let defaults: UserDefaults

    private enum Key {
        static let tone = "tone"
        static let customApproach = "customApproach"
        static let minLength = "minLength"
        static let maxLength = "maxLength"
        static let provider = "provider"
        static let apiKey = "geminiAPIKey"
        static let model = "geminiModel"
    }

    public init(defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) {
        // Fall back to standard defaults only if the App Group is not
        // configured yet (for example before the group is registered in
        // the Apple Developer portal). The keyboard and the app must use
        // the same group or settings will not sync between them.
        self.defaults = defaults ?? .standard
    }

    @Published public var tone: Tone {
        get {
            guard let raw = defaults.string(forKey: Key.tone),
                  let tone = Tone(rawValue: raw) else { return .playfulTease }
            return tone
        }
        set { defaults.set(newValue.rawValue, forKey: Key.tone) }
    }

    @Published public var customApproach: String {
        get { defaults.string(forKey: Key.customApproach) ?? "" }
        set { defaults.set(newValue, forKey: Key.customApproach) }
    }

    /// Minimum reply length in characters.
    @Published public var minLength: Int {
        get {
            let value = defaults.integer(forKey: Key.minLength)
            return value == 0 ? 10 : value
        }
        set { defaults.set(newValue, forKey: Key.minLength) }
    }

    /// Maximum reply length in characters.
    @Published public var maxLength: Int {
        get {
            let value = defaults.integer(forKey: Key.maxLength)
            return value == 0 ? 140 : value
        }
        set { defaults.set(newValue, forKey: Key.maxLength) }
    }

    @Published public var provider: AIProvider {
        get {
            guard let raw = defaults.string(forKey: Key.provider),
                  let provider = AIProvider(rawValue: raw) else { return .gemini }
            return provider
        }
        set { defaults.set(newValue.rawValue, forKey: Key.provider) }
    }

    /// Gemini API key, entered in the container app.
    /// See the class comment: v1 stores this in shared UserDefaults.
    /// TODO: move to shared Keychain.
    public var apiKey: String {
        get { defaults.string(forKey: Key.apiKey) ?? "" }
        set { defaults.set(newValue, forKey: Key.apiKey) }
    }

    public var hasAPIKey: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Gemini model name, for example "gemini-2.5-flash".
    public var model: String {
        get {
            let stored = defaults.string(forKey: Key.model) ?? ""
            return stored.isEmpty ? "gemini-2.5-flash" : stored
        }
        set { defaults.set(newValue, forKey: Key.model) }
    }
}

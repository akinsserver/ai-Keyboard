import Foundation

/// The reply style the user picked in the keyboard top bar or in Settings.
/// `custom` uses the free-text approach the user typed in Settings.
public enum Tone: String, CaseIterable, Identifiable, Codable {
    case playfulTease = "playful_tease"
    case properEnglish = "proper_english"
    case uppercase = "uppercase"
    case custom = "custom"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .playfulTease: return "Playful tease"
        case .properEnglish: return "Proper English"
        case .uppercase: return "Uppercase"
        case .custom: return "Custom approach"
        }
    }

    /// Short instruction fragment inserted into the suggestion prompt.
    /// For `.custom`, the call site appends the user's free-text approach.
    public var promptInstruction: String {
        switch self {
        case .playfulTease:
            return "Write in a playful, light-hearted, teasing style. Flirty but friendly, never rude or crude."
        case .properEnglish:
            return "Write in correct, proper English with good grammar and punctuation. Clear and polite."
        case .uppercase:
            return "Write the reply in ALL UPPERCASE LETTERS."
        case .custom:
            return "Follow the custom approach given below."
        }
    }
}

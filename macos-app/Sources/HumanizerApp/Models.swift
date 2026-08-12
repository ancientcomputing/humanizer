import Foundation

enum LLMProvider: String, CaseIterable, Codable {
    case anthropic
    case openai
}

struct VoiceRule: Codable, Identifiable, Equatable {
    var id: String
    var description: String
    var exampleBefore: String
    var exampleAfter: String
    var category: String
    var confidence: String
    var sourceCount: Int

    enum CodingKeys: String, CodingKey {
        case id, description, category, confidence
        case exampleBefore = "example_before"
        case exampleAfter = "example_after"
        case sourceCount = "source_count"
    }
}

struct LexicalPreferences: Codable, Equatable {
    var avoid: [String] = []
    var prefer: [String] = []
}

struct VoiceProfileHistoryEntry: Codable, Equatable {
    var date: String
    var articleId: String
    var editsAbsorbed: Int

    enum CodingKeys: String, CodingKey {
        case date
        case articleId = "article_id"
        case editsAbsorbed = "edits_absorbed"
    }
}

struct VoiceProfileData: Codable, Equatable {
    var version: Int = 1
    var lastUpdated: String = ""
    var rules: [VoiceRule] = []
    var lexicalPreferences: LexicalPreferences = LexicalPreferences()
    var structuralNotes: [String] = []
    var history: [VoiceProfileHistoryEntry] = []

    enum CodingKeys: String, CodingKey {
        case version, rules, history
        case lastUpdated = "last_updated"
        case lexicalPreferences = "lexical_preferences"
        case structuralNotes = "structural_notes"
    }

    static func empty() -> VoiceProfileData {
        VoiceProfileData(version: 1, lastUpdated: isoToday(), rules: [], lexicalPreferences: LexicalPreferences(), structuralNotes: [], history: [])
    }
}

func isoToday() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    return formatter.string(from: Date())
}

func confidenceForCount(_ count: Int) -> String {
    if count >= 4 { return "high" }
    if count >= 2 { return "medium" }
    return "low"
}

enum PipelineError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

import Foundation

enum LLMProvider: String, CaseIterable, Codable {
    case anthropic
    case openai
}

struct RuleExample: Codable, Equatable {
    var before: String
    var after: String
}

/// A rule keeps a small, capped set of examples (see VoiceProfileStore.maxExamplesPerRule)
/// rather than a single before/after pair, so a broad, frequently-reinforced rule (e.g. one
/// covering several different sentence shapes) can show more than one illustration in the
/// prompt instead of the most recent reinforcement silently overwriting the last one.
struct VoiceRule: Codable, Identifiable, Equatable {
    var id: String
    var description: String
    var examples: [RuleExample]
    var category: String
    var confidence: String
    var sourceCount: Int

    enum CodingKeys: String, CodingKey {
        case id, description, examples, category, confidence
        case sourceCount = "source_count"
        // Legacy single-example fields, read for backward compatibility with
        // profiles saved before examples became a list.
        case legacyExampleBefore = "example_before"
        case legacyExampleAfter = "example_after"
    }

    init(id: String, description: String, examples: [RuleExample], category: String, confidence: String, sourceCount: Int) {
        self.id = id
        self.description = description
        self.examples = examples
        self.category = category
        self.confidence = confidence
        self.sourceCount = sourceCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        description = try container.decode(String.self, forKey: .description)
        category = try container.decode(String.self, forKey: .category)
        confidence = try container.decode(String.self, forKey: .confidence)
        sourceCount = try container.decode(Int.self, forKey: .sourceCount)

        if let decoded = try container.decodeIfPresent([RuleExample].self, forKey: .examples) {
            examples = decoded
        } else {
            let before = (try container.decodeIfPresent(String.self, forKey: .legacyExampleBefore)) ?? ""
            let after = (try container.decodeIfPresent(String.self, forKey: .legacyExampleAfter)) ?? ""
            examples = (before.isEmpty || after.isEmpty) ? [] : [RuleExample(before: before, after: after)]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(description, forKey: .description)
        try container.encode(examples, forKey: .examples)
        try container.encode(category, forKey: .category)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(sourceCount, forKey: .sourceCount)
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

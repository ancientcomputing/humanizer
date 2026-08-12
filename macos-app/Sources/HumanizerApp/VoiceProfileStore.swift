import Foundation
import Combine

struct RuleUpdateAction {
    var action: String // "new" | "reinforced"
    var id: String
    var description: String
    var sourceCount: Int
    var confidence: String
}

struct MergeResult {
    var id: String
    var description: String
    var confidence: String
    var sourceCount: Int
    var mergedFromCount: Int
}

@MainActor
final class VoiceProfileStore: ObservableObject {
    @Published var data: VoiceProfileData

    private let path: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(path: URL = AppPaths.voiceProfilePath) {
        self.path = path
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.data = VoiceProfileData.empty()
        AppPaths.migrateLegacySandboxedVoiceProfileIfNeeded()
        self.data = Self.load(path: path, decoder: decoder)
    }

    private static func load(path: URL, decoder: JSONDecoder) -> VoiceProfileData {
        guard let raw = try? Data(contentsOf: path),
              let decoded = try? decoder.decode(VoiceProfileData.self, from: raw) else {
            return VoiceProfileData.empty()
        }
        return decoded
    }

    func reload() {
        data = Self.load(path: path, decoder: decoder)
    }

    func save() {
        data.lastUpdated = isoToday()
        guard let encoded = try? encoder.encode(data) else { return }
        try? FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? encoded.write(to: path, options: .atomic)
    }

    var isEmpty: Bool {
        data.rules.isEmpty && data.lexicalPreferences.avoid.isEmpty
    }

    func nextRuleID() -> String {
        let numbers: [Int] = data.rules.compactMap { rule in
            guard rule.id.hasPrefix("rule_") else { return nil }
            return Int(rule.id.dropFirst("rule_".count))
        }
        let next = (numbers.max() ?? 0) + 1
        return String(format: "rule_%03d", next)
    }

    func findSimilarRule(description: String) -> VoiceRule? {
        let normalized = description.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return data.rules.first { $0.description.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized }
    }

    func findRule(id: String) -> VoiceRule? {
        data.rules.first { $0.id == id }
    }

    func rulesContextForMatching() -> String {
        if data.rules.isEmpty { return "(none yet)" }
        return data.rules.map { "- \($0.id): \($0.description)" }.joined(separator: "\n")
    }

    /// Ported from VoiceProfile.apply_rule_updates.
    @discardableResult
    func applyRuleUpdates(_ updates: [ClassifyRuleUpdate], articleID: String) -> [RuleUpdateAction] {
        var actions: [RuleUpdateAction] = []

        for update in updates {
            let description = (update.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !description.isEmpty else { continue }

            let matchedID = (update.matchedRuleID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            var existingIndex: Int?
            if !matchedID.isEmpty {
                existingIndex = data.rules.firstIndex { $0.id == matchedID }
            }
            if existingIndex == nil {
                let normalized = description.lowercased()
                existingIndex = data.rules.firstIndex { $0.description.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized }
            }

            if let idx = existingIndex {
                data.rules[idx].sourceCount += 1
                data.rules[idx].confidence = confidenceForCount(data.rules[idx].sourceCount)
                if let before = update.exampleBefore, let after = update.exampleAfter, !before.isEmpty, !after.isEmpty {
                    data.rules[idx].exampleBefore = before
                    data.rules[idx].exampleAfter = after
                }
                actions.append(RuleUpdateAction(
                    action: "reinforced",
                    id: data.rules[idx].id,
                    description: data.rules[idx].description,
                    sourceCount: data.rules[idx].sourceCount,
                    confidence: data.rules[idx].confidence
                ))
            } else {
                let newRule = VoiceRule(
                    id: nextRuleID(),
                    description: description,
                    exampleBefore: update.exampleBefore ?? "",
                    exampleAfter: update.exampleAfter ?? "",
                    category: update.category ?? "tone",
                    confidence: "low",
                    sourceCount: 1
                )
                data.rules.append(newRule)
                actions.append(RuleUpdateAction(
                    action: "new",
                    id: newRule.id,
                    description: newRule.description,
                    sourceCount: 1,
                    confidence: "low"
                ))
            }
        }

        data.history.append(VoiceProfileHistoryEntry(date: isoToday(), articleId: articleID, editsAbsorbed: actions.count))
        return actions
    }

    func rulesAsJSON() -> String {
        guard let encoded = try? encoder.encode(data.rules), let string = String(data: encoded, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    /// Ported from VoiceProfile.replace_with_clusters.
    @discardableResult
    func replaceWithClusters(_ clusters: [ConsolidateCluster]) -> (Int, [MergeResult]) {
        var rulesByID: [String: VoiceRule] = [:]
        for rule in data.rules where !rule.id.isEmpty {
            rulesByID[rule.id] = rule
        }
        var seenIDs = Set<String>()
        var newRules: [VoiceRule] = []
        var merges: [MergeResult] = []

        for (index, cluster) in clusters.enumerated() {
            let sourceIDs = (cluster.sourceRuleIDs ?? []).filter { rulesByID[$0] != nil }
            guard !sourceIDs.isEmpty else { continue }

            let mergedCount = sourceIDs.reduce(0) { $0 + (rulesByID[$1]?.sourceCount ?? 1) }
            var description = (cluster.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if description.isEmpty {
                description = rulesByID[sourceIDs[0]]?.description ?? ""
            }

            let newRule = VoiceRule(
                id: String(format: "rule_%03d", index + 1),
                description: description,
                exampleBefore: cluster.exampleBefore ?? rulesByID[sourceIDs[0]]?.exampleBefore ?? "",
                exampleAfter: cluster.exampleAfter ?? rulesByID[sourceIDs[0]]?.exampleAfter ?? "",
                category: cluster.category ?? rulesByID[sourceIDs[0]]?.category ?? "tone",
                confidence: confidenceForCount(mergedCount),
                sourceCount: mergedCount
            )
            newRules.append(newRule)
            seenIDs.formUnion(sourceIDs)

            if sourceIDs.count > 1 {
                merges.append(MergeResult(
                    id: newRule.id,
                    description: newRule.description,
                    confidence: newRule.confidence,
                    sourceCount: newRule.sourceCount,
                    mergedFromCount: sourceIDs.count
                ))
            }
        }

        var nextIndex = newRules.count + 1
        for (ruleID, rule) in rulesByID where !seenIDs.contains(ruleID) {
            var copy = rule
            copy.id = String(format: "rule_%03d", nextIndex)
            newRules.append(copy)
            nextIndex += 1
        }

        data.rules = newRules
        return (newRules.count, merges)
    }

    func addLexicalAvoid(_ phrases: [String]) {
        for phrase in phrases {
            let normalized = phrase.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !normalized.isEmpty && !data.lexicalPreferences.avoid.contains(normalized) {
                data.lexicalPreferences.avoid.append(normalized)
            }
        }
    }

    /// Ported from VoiceProfile.as_prompt_context.
    func asPromptContext() -> String {
        if isEmpty { return "(No voice profile yet — no learned rules to apply.)" }

        var lines: [String] = []
        let rules = data.rules.sorted { $0.sourceCount > $1.sourceCount }
        if !rules.isEmpty {
            lines.append("Voice rules (higher confidence = more reliable):")
            for rule in rules {
                var line = "- [\(rule.confidence)] \(rule.description)"
                if !rule.exampleBefore.isEmpty && !rule.exampleAfter.isEmpty {
                    line += " (e.g. \"\(rule.exampleBefore)\" -> \"\(rule.exampleAfter)\")"
                }
                lines.append(line)
            }
        }

        if !data.lexicalPreferences.avoid.isEmpty {
            lines.append("\nAvoid these words/phrases: " + data.lexicalPreferences.avoid.joined(separator: ", "))
        }
        if !data.lexicalPreferences.prefer.isEmpty {
            lines.append("Prefer these words/phrases: " + data.lexicalPreferences.prefer.joined(separator: ", "))
        }

        if !data.structuralNotes.isEmpty {
            lines.append("\nStructural tendencies:")
            for note in data.structuralNotes {
                lines.append("- \(note)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

import Foundation

// MARK: - LLM JSON response shapes

struct ClassifyChange: Codable {
    var originalSnippet: String?
    var editedSnippet: String?
    var classification: String?
    var reasoning: String?

    enum CodingKeys: String, CodingKey {
        case classification, reasoning
        case originalSnippet = "original_snippet"
        case editedSnippet = "edited_snippet"
    }
}

struct ClassifyRuleUpdate: Codable {
    var matchedRuleID: String?
    var description: String?
    var exampleBefore: String?
    var exampleAfter: String?
    var category: String?

    enum CodingKeys: String, CodingKey {
        case description, category
        case matchedRuleID = "matched_rule_id"
        case exampleBefore = "example_before"
        case exampleAfter = "example_after"
    }
}

struct ClassifyResponse: Codable {
    var changes: [ClassifyChange] = []
    var ruleUpdates: [ClassifyRuleUpdate] = []

    enum CodingKeys: String, CodingKey {
        case changes
        case ruleUpdates = "rule_updates"
    }
}

struct ConsolidateCluster: Codable {
    var description: String?
    var category: String?
    var exampleBefore: String?
    var exampleAfter: String?
    var sourceRuleIDs: [String]?

    enum CodingKeys: String, CodingKey {
        case description, category
        case exampleBefore = "example_before"
        case exampleAfter = "example_after"
        case sourceRuleIDs = "source_rule_ids"
    }
}

struct ConsolidateResponse: Codable {
    var clusters: [ConsolidateCluster] = []
}

// MARK: - Results surfaced to the UI

struct HumanizeResult {
    var draft: String
    var usedVoiceProfile: Bool
    /// The output of the first (humanize) pass, before the verify pass ran —
    /// nil if the verify pass didn't run. Surfaced in the UI for debugging
    /// which pass introduced a given change.
    var preVerifyDraft: String?
}

struct ReviewResult {
    var mismatch: Bool
    var message: String?
    var changes: [ClassifyChange]
    var styleCount: Int
    var contentCount: Int
    var editsAbsorbed: Int
    var summary: String
    var newRules: [RuleUpdateAction]
    var reinforcedRules: [RuleUpdateAction]
    var merges: [MergeResult]
}

struct ConsolidateResult {
    var beforeCount: Int
    var afterCount: Int
    var changed: Bool
    var merges: [MergeResult]
}

@MainActor
enum Pipeline {
    static func humanize(provider: Provider, maxTokens: Int, voiceProfile: VoiceProfileStore, draft: String, platform: String) async throws -> HumanizeResult {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PipelineError.message("Draft text is empty.")
        }

        let usedVoiceProfile = !voiceProfile.isEmpty
        let voiceSection = usedVoiceProfile
            ? voiceProfile.asPromptContext()
            : "No voice profile yet — apply only the generic AI-tell stripping above."

        let system = PromptTemplates.render(PromptTemplates.humanizeSystem, [
            "voice_section": voiceSection,
            "platform": platform.isEmpty ? "Other" : platform,
        ])
        let user = PromptTemplates.render(PromptTemplates.humanizeUser, ["draft": draft])

        var output: String
        do {
            output = try await provider.complete(system: system, user: user, maxTokens: maxTokens)
        } catch let error as ProviderError {
            throw PipelineError.message(error.errorDescription ?? "Provider error.")
        }

        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PipelineError.message("The provider returned an empty response.")
        }
        output = output.trimmingCharacters(in: .whitespacesAndNewlines)

        let preVerifyDraft = output
        let mandatoryRules = voiceProfile.mandatoryRulesContext()
        if !mandatoryRules.isEmpty {
            output = await verify(provider: provider, maxTokens: maxTokens, mandatoryRules: mandatoryRules, draft: output)
        }

        return HumanizeResult(
            draft: output,
            usedVoiceProfile: usedVoiceProfile,
            preVerifyDraft: mandatoryRules.isEmpty ? nil : preVerifyDraft
        )
    }

    /// Second pass: check draft against mandatory (high-confidence) rules and fix any
    /// missed instances. Falls back to the unverified draft if this call fails, since a
    /// failed proofreading pass shouldn't block humanize.
    private static func verify(provider: Provider, maxTokens: Int, mandatoryRules: String, draft: String) async -> String {
        let system = PromptTemplates.render(PromptTemplates.verifySystem, ["mandatory_rules": mandatoryRules])
        let user = PromptTemplates.render(PromptTemplates.verifyUser, ["draft": draft])

        guard let output = try? await provider.complete(system: system, user: user, maxTokens: maxTokens) else {
            return draft
        }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? draft : trimmed
    }

    static func review(provider: Provider, maxTokens: Int, mismatchThreshold: Double, voiceProfile: VoiceProfileStore, humanizedText: String, editedText: String) async throws -> ReviewResult {
        let humanized = humanizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let edited = editedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !humanized.isEmpty, !edited.isEmpty else {
            throw PipelineError.message("Both the humanized draft and the edited version are required.")
        }

        if Diffing.isLikelyMismatch(humanized, edited, threshold: mismatchThreshold) {
            return ReviewResult(
                mismatch: true,
                message: "This looks like a different article, not an edit — check your paste.",
                changes: [], styleCount: 0, contentCount: 0, editsAbsorbed: 0,
                summary: "", newRules: [], reinforcedRules: [], merges: []
            )
        }

        let classification = try await classify(provider: provider, maxTokens: maxTokens, voiceProfile: voiceProfile, original: humanized, edited: edited)

        let styleCount = classification.changes.filter { $0.classification == "style" }.count
        let contentCount = classification.changes.filter { $0.classification == "content" }.count

        let articleID = UUID().uuidString.prefix(8).lowercased()
        let actions = voiceProfile.applyRuleUpdates(classification.ruleUpdates, articleID: String(articleID))
        voiceProfile.save()

        let newRules = actions.filter { $0.action == "new" }
        let reinforcedRules = actions.filter { $0.action == "reinforced" }

        var merges: [MergeResult] = []
        if voiceProfile.data.rules.count >= 2 {
            merges = (try? await consolidateInternal(provider: provider, maxTokens: maxTokens, voiceProfile: voiceProfile)) ?? []
        }

        let summary = "\(styleCount) style edit\(styleCount != 1 ? "s" : "") (added to voice profile), " +
            "\(contentCount) content edit\(contentCount != 1 ? "s" : "") (ignored for learning)."

        return ReviewResult(
            mismatch: false,
            message: nil,
            changes: classification.changes,
            styleCount: styleCount,
            contentCount: contentCount,
            editsAbsorbed: actions.count,
            summary: summary,
            newRules: newRules,
            reinforcedRules: reinforcedRules,
            merges: merges
        )
    }

    static func consolidateVoiceProfile(provider: Provider, maxTokens: Int, voiceProfile: VoiceProfileStore) async throws -> ConsolidateResult {
        let beforeCount = voiceProfile.data.rules.count
        let merges = try await consolidateInternal(provider: provider, maxTokens: maxTokens, voiceProfile: voiceProfile)
        let afterCount = voiceProfile.data.rules.count
        return ConsolidateResult(beforeCount: beforeCount, afterCount: afterCount, changed: afterCount != beforeCount, merges: merges)
    }

    private static func consolidateInternal(provider: Provider, maxTokens: Int, voiceProfile: VoiceProfileStore) async throws -> [MergeResult] {
        guard voiceProfile.data.rules.count >= 2 else { return [] }

        let system = PromptTemplates.consolidateSystem
        let user = PromptTemplates.render(PromptTemplates.consolidateUser, ["rules_json": voiceProfile.rulesAsJSON()])

        let raw: String
        do {
            raw = try await provider.complete(system: system, user: user, maxTokens: maxTokens)
        } catch let error as ProviderError {
            throw PipelineError.message(error.errorDescription ?? "Provider error.")
        }

        let parsed: ConsolidateResponse = try parseJSONResponse(raw, label: "consolidation")
        let (_, merges) = voiceProfile.replaceWithClusters(parsed.clusters)
        voiceProfile.save()
        return merges
    }

    private static func classify(provider: Provider, maxTokens: Int, voiceProfile: VoiceProfileStore, original: String, edited: String) async throws -> ClassifyResponse {
        let diffText = Diffing.unifiedDiff(original, edited)
        let system = PromptTemplates.classifySystem
        let user = PromptTemplates.render(PromptTemplates.classifyUser, [
            "original": original,
            "edited": edited,
            "diff": diffText,
            "existing_rules": voiceProfile.rulesContextForMatching(),
        ])

        let raw: String
        do {
            raw = try await provider.complete(system: system, user: user, maxTokens: maxTokens)
        } catch let error as ProviderError {
            throw PipelineError.message(error.errorDescription ?? "Provider error.")
        }

        return try parseJSONResponse(raw, label: "classifier")
    }

    private static func parseJSONResponse<T: Decodable>(_ raw: String, label: String) throws -> T {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text.trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            if text.hasPrefix("json") {
                text = String(text.dropFirst(4))
            }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let data = text.data(using: .utf8) else {
            throw PipelineError.message("The \(label) response could not be parsed as JSON. Try again.")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PipelineError.message("The \(label) response could not be parsed as JSON. Try again.")
        }
    }
}

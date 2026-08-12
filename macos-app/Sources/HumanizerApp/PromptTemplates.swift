import Foundation

/// Loads prompt templates from prompts/*.md, synced into the resource
/// bundle at build time by the SyncPrompts plugin (see Package.swift).
/// prompts/*.md is the single source of truth, shared with the Python
/// backend (core/prompts.py); do not hardcode prompt text here.
enum PromptTemplates {
    private static func loadTemplate(_ name: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "md", subdirectory: "Resources/Prompts")
            ?? Bundle.module.url(forResource: name, withExtension: "md")
        else {
            fatalError("Prompt template not found: \(name).md")
        }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            fatalError("Failed to read prompt template: \(name).md")
        }
        return text
    }

    /// Ported from core/prompts.split_system_user — splits on '## System' / '## User' headers.
    private static func splitSystemUser(_ template: String) -> (system: String, user: String) {
        let systemMarker = "## System"
        let userMarker = "## User"
        guard let systemRange = template.range(of: systemMarker),
              let userRange = template.range(of: userMarker)
        else {
            fatalError("Prompt template missing '## System' or '## User' section")
        }
        let system = template[systemRange.upperBound..<userRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let user = template[userRange.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (system, user)
    }

    static func render(_ template: String, _ values: [String: String]) -> String {
        var result = template
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }

    private static func section(_ file: String) -> (system: String, user: String) {
        splitSystemUser(loadTemplate(file))
    }

    static var humanizeSystem: String { section("humanize").system }
    static var humanizeUser: String { section("humanize").user }
    static var classifySystem: String { section("classify").system }
    static var classifyUser: String { section("classify").user }
    static var consolidateSystem: String { section("consolidate").system }
    static var consolidateUser: String { section("consolidate").user }
    static var verifySystem: String { section("verify").system }
    static var verifyUser: String { section("verify").user }
}

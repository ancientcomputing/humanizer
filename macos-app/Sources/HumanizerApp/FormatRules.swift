import Foundation

enum FormatRules {
    static let platforms = ["Reddit", "LinkedIn", "Other"]

    /// Mechanical, platform-specific formatting only — never touches voice.
    static func apply(_ text: String, platform: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch platform {
        case "Reddit": return formatReddit(trimmed)
        case "LinkedIn": return formatLinkedIn(trimmed)
        default: return trimmed
        }
    }

    private static func formatReddit(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(
            of: #"(?<!\S)#\w+"#, with: "", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"[ \t]+\n"#, with: "\n", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\n{3,}"#, with: "\n\n", options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatLinkedIn(_ text: String) -> String {
        let paragraphs = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return paragraphs.joined(separator: "\n\n")
    }
}

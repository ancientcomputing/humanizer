import Foundation

enum Diffing {
    /// Rough word-level similarity, 0..1. Cheap heuristic, not exact — mirrors
    /// difflib's SequenceMatcher.ratio() closely enough for a mismatch threshold check.
    static func similarityRatio(_ a: String, _ b: String) -> Double {
        let aWords = a.split(separator: " ").map(String.init)
        let bWords = b.split(separator: " ").map(String.init)
        if aWords.isEmpty && bWords.isEmpty { return 1.0 }

        let diff = bWords.difference(from: aWords)
        let insertions = diff.insertions.count
        let removals = diff.removals.count
        let matched = aWords.count - removals
        let total = aWords.count + bWords.count
        guard total > 0 else { return 1.0 }
        _ = insertions
        return (2.0 * Double(matched)) / Double(total)
    }

    static func isLikelyMismatch(_ a: String, _ b: String, threshold: Double) -> Bool {
        similarityRatio(a, b) < threshold
    }

    /// A line-based diff formatted for LLM context. Not a strict unified-diff
    /// patch format, but close enough to give the classifier prompt useful context.
    static func unifiedDiff(_ a: String, _ b: String, fromLabel: String = "original", toLabel: String = "edited") -> String {
        let aLines = a.components(separatedBy: "\n")
        let bLines = b.components(separatedBy: "\n")
        let diff = bLines.difference(from: aLines)

        var removedByOffset: [Int: String] = [:]
        var insertedByOffset: [Int: String] = [:]
        for change in diff {
            switch change {
            case let .remove(offset, element, _):
                removedByOffset[offset] = element
            case let .insert(offset, element, _):
                insertedByOffset[offset] = element
            }
        }

        var lines: [String] = ["--- \(fromLabel)", "+++ \(toLabel)"]
        for (offset, line) in aLines.enumerated() {
            if let removed = removedByOffset[offset] {
                lines.append("-\(removed)")
            } else {
                _ = line
            }
        }
        for (offset, line) in bLines.enumerated() {
            if let inserted = insertedByOffset[offset] {
                lines.append("+\(inserted)")
            } else {
                _ = line
            }
        }
        return lines.joined(separator: "\n")
    }
}

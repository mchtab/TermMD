import Foundation

/// Builds the natural-language prompt that gets injected into the terminal for Claude Code.
struct SendToClaudeBuilder {

    /// "With line refs" variant — includes file path, line range, and snippet.
    static func buildWithLineRefs(
        fileURL: URL?,
        lineRange: ClosedRange<Int>?,
        selectedText: String
    ) -> String {
        let filePath = fileURL?.path ?? "Untitled (unsaved)"
        let lines: String
        if let range = lineRange {
            lines = "lines \(range.lowerBound)-\(range.upperBound)"
        } else {
            lines = "unknown lines"
        }
        return "I am working on the file: \(filePath)\n\nThe selected text at \(lines) is:\n\n```\n\(selectedText)\n```\n\nPlease read this file first, then make the following change: "
    }

    /// "Selection only" variant — no file/line metadata.
    static func buildSelectionOnly(selectedText: String) -> String {
        return "Here is a snippet I'm working on:\n\n```\n\(selectedText)\n```\n\nPlease make the following change: "
    }
}

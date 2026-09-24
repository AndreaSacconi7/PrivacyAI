import Foundation

/// Splits a reply into plain Markdown and fenced ``` code blocks.
enum MarkdownSegment: Equatable {
    case text(String)
    case code(String)

    static func parse(_ input: String) -> [MarkdownSegment] {
        input.components(separatedBy: "```").enumerated().compactMap { index, component in
            if index.isMultiple(of: 2) {
                let text = component.trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? nil : .text(text)
            }
            // Drop the language hint on the opening fence, e.g. "swift".
            var lines = component.components(separatedBy: .newlines)
            if lines.count > 1, !lines[0].contains(" ") {
                lines.removeFirst()
            }
            return .code(lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

import SwiftUI

struct MarkdownPreviewView: View {
    @EnvironmentObject var notesManager: NotesManager
    let content: String

    var body: some View {
        ScrollView {
            MarkdownContent(
                content: content,
                textFont: notesManager.textFont,
                codeFont: notesManager.codeFont
            )
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }
}

struct MarkdownContent: View {
    let content: String
    let textFont: FontSetting
    let codeFont: FontSetting

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                block
            }
        }
    }

    private func parseBlocks() -> [AnyView] {
        let lines = content.components(separatedBy: "\n")
        var result: [AnyView] = []
        var inCodeBlock = false
        var codeBlockContent: [String] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]

            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    let code = codeBlockContent.joined(separator: "\n")
                    result.append(AnyView(
                        Text(code)
                            .font(codeFont.font)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    ))
                    codeBlockContent = []
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                }
            } else if inCodeBlock {
                codeBlockContent.append(line)
            } else {
                result.append(AnyView(renderLine(line)))
            }
            i += 1
        }

        return result
    }

    @ViewBuilder
    private func renderLine(_ line: String) -> some View {
        if line.hasPrefix("######") {
            Text(line.dropFirst(6).trimmingCharacters(in: .whitespaces))
                .font(.system(size: textFont.size * 1.1, weight: .semibold))
        } else if line.hasPrefix("#####") {
            Text(line.dropFirst(5).trimmingCharacters(in: .whitespaces))
                .font(.system(size: textFont.size * 1.15, weight: .semibold))
        } else if line.hasPrefix("####") {
            Text(line.dropFirst(4).trimmingCharacters(in: .whitespaces))
                .font(.system(size: textFont.size * 1.2, weight: .bold))
        } else if line.hasPrefix("###") {
            Text(line.dropFirst(3).trimmingCharacters(in: .whitespaces))
                .font(.system(size: textFont.size * 1.3, weight: .bold))
        } else if line.hasPrefix("##") {
            Text(line.dropFirst(2).trimmingCharacters(in: .whitespaces))
                .font(.system(size: textFont.size * 1.5, weight: .bold))
        } else if line.hasPrefix("#") {
            Text(line.dropFirst(1).trimmingCharacters(in: .whitespaces))
                .font(.system(size: textFont.size * 1.8, weight: .bold))
        } else if line.hasPrefix(">") {
            Text(line.dropFirst(1).trimmingCharacters(in: .whitespaces))
                .font(textFont.font)
                .foregroundColor(.secondary)
                .padding(.leading, 12)
                .overlay(
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 3),
                    alignment: .leading
                )
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(textFont.font)
                renderInlineMarkdown(String(line.dropFirst(2)))
            }
        } else if line.trimmingCharacters(in: .whitespaces) == "---" {
            Divider()
        } else if !line.isEmpty {
            renderInlineMarkdown(line)
        } else {
            Spacer().frame(height: 8)
        }
    }

    @ViewBuilder
    private func renderInlineMarkdown(_ text: String) -> some View {
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
                .font(textFont.font)
        } else {
            Text(text)
                .font(textFont.font)
        }
    }
}

#Preview {
    MarkdownPreviewView(content: """
    # Hello World

    This is **bold** and *italic* text.

    ## Code Example

    ```
    let x = 42
    print(x)
    ```

    Inline `code` works too.

    - Item 1
    - Item 2
    - Item 3

    > This is a blockquote

    [Link](https://example.com)
    """)
    .environmentObject(NotesManager())
    .frame(width: 400, height: 500)
}

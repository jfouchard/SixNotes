import SwiftUI

struct MarkdownPreviewView: View {
    @EnvironmentObject var notesManager: NotesManager
    let content: String

    var body: some View {
        MarkdownTextView(
            content: content,
            textFont: notesManager.textFont.nsFont,
            codeFont: notesManager.codeFont.nsFont
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MarkdownTextView: NSViewRepresentable {
    let content: String
    let textFont: NSFont
    let codeFont: NSFont

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.drawsBackground = false

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        updateTextView(textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        updateTextView(textView)
    }

    private func updateTextView(_ textView: NSTextView) {
        let attributedString = renderMarkdown()
        textView.textStorage?.setAttributedString(attributedString)
    }

    private func renderMarkdown() -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = content.components(separatedBy: "\n")
        var inCodeBlock = false
        var codeBlockLines: [String] = []

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        for line in lines {
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    let code = codeBlockLines.joined(separator: "\n")
                    let codeAttr = NSMutableAttributedString(string: code + "\n\n", attributes: [
                        .font: codeFont,
                        .backgroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.1),
                        .paragraphStyle: paragraphStyle
                    ])
                    result.append(codeAttr)
                    codeBlockLines = []
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeBlockLines.append(line)
                continue
            }

            // Headers
            if line.hasPrefix("######") {
                appendHeader(to: result, text: String(line.dropFirst(6)), scale: 1.1, weight: .semibold)
            } else if line.hasPrefix("#####") {
                appendHeader(to: result, text: String(line.dropFirst(5)), scale: 1.15, weight: .semibold)
            } else if line.hasPrefix("####") {
                appendHeader(to: result, text: String(line.dropFirst(4)), scale: 1.2, weight: .bold)
            } else if line.hasPrefix("###") {
                appendHeader(to: result, text: String(line.dropFirst(3)), scale: 1.3, weight: .bold)
            } else if line.hasPrefix("##") {
                appendHeader(to: result, text: String(line.dropFirst(2)), scale: 1.5, weight: .bold)
            } else if line.hasPrefix("#") {
                appendHeader(to: result, text: String(line.dropFirst(1)), scale: 1.8, weight: .bold)
            } else if line.hasPrefix(">") {
                // Blockquote
                let text = line.dropFirst(1).trimmingCharacters(in: .whitespaces)
                let blockquoteStyle = NSMutableParagraphStyle()
                blockquoteStyle.firstLineHeadIndent = 12
                blockquoteStyle.headIndent = 12
                blockquoteStyle.lineSpacing = 4
                let attr = NSAttributedString(string: text + "\n", attributes: [
                    .font: textFont,
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: blockquoteStyle
                ])
                result.append(attr)
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                // List item
                let text = String(line.dropFirst(2))
                let listStyle = NSMutableParagraphStyle()
                listStyle.firstLineHeadIndent = 0
                listStyle.headIndent = 16
                listStyle.lineSpacing = 4
                result.append(NSAttributedString(string: "• ", attributes: [
                    .font: textFont,
                    .paragraphStyle: listStyle
                ]))
                appendInlineMarkdown(to: result, text: text + "\n")
            } else if line.trimmingCharacters(in: .whitespaces) == "---" {
                result.append(NSAttributedString(string: "―――――――――――――――――――\n", attributes: [
                    .font: textFont,
                    .foregroundColor: NSColor.separatorColor
                ]))
            } else if !line.isEmpty {
                appendInlineMarkdown(to: result, text: line + "\n")
            } else {
                result.append(NSAttributedString(string: "\n"))
            }
        }

        return result
    }

    private func appendHeader(to result: NSMutableAttributedString, text: String, scale: CGFloat, weight: NSFont.Weight) {
        let headerFont = NSFont.systemFont(ofSize: textFont.pointSize * scale, weight: weight)
        let headerStyle = NSMutableParagraphStyle()
        headerStyle.lineSpacing = 4
        headerStyle.paragraphSpacingBefore = 8
        let attr = NSAttributedString(string: text.trimmingCharacters(in: .whitespaces) + "\n", attributes: [
            .font: headerFont,
            .paragraphStyle: headerStyle
        ])
        result.append(attr)
    }

    private func appendInlineMarkdown(to result: NSMutableAttributedString, text: String) {
        // Try to parse inline markdown (bold, italic, code, links)
        if let attributed = try? NSAttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            let mutable = NSMutableAttributedString(attributedString: attributed)
            // Enumerate existing fonts and preserve traits while updating to base font size
            mutable.enumerateAttribute(.font, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
                if let existingFont = value as? NSFont {
                    let traits = NSFontManager.shared.traits(of: existingFont)
                    var newFont = textFont
                    if traits.contains(.boldFontMask) && traits.contains(.italicFontMask) {
                        newFont = NSFontManager.shared.convert(textFont, toHaveTrait: [.boldFontMask, .italicFontMask])
                    } else if traits.contains(.boldFontMask) {
                        newFont = NSFontManager.shared.convert(textFont, toHaveTrait: .boldFontMask)
                    } else if traits.contains(.italicFontMask) {
                        newFont = NSFontManager.shared.convert(textFont, toHaveTrait: .italicFontMask)
                    }
                    mutable.addAttribute(.font, value: newFont, range: range)
                } else {
                    mutable.addAttribute(.font, value: textFont, range: range)
                }
            }
            // Apply paragraph style
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4
            mutable.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: mutable.length))
            result.append(mutable)
        } else {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4
            result.append(NSAttributedString(string: text, attributes: [
                .font: textFont,
                .paragraphStyle: paragraphStyle
            ]))
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

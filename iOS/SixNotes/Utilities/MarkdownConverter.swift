import UIKit
import Foundation

// Custom attribute keys for preserving markdown metadata
extension NSAttributedString.Key {
    static let markdownHeaderLevel = NSAttributedString.Key("markdownHeaderLevel")
    static let markdownBlockType = NSAttributedString.Key("markdownBlockType")
    static let markdownListPrefix = NSAttributedString.Key("markdownListPrefix")
}

enum MarkdownBlockType: String {
    case paragraph
    case header
    case codeBlock
    case blockquote
    case listItem
    case horizontalRule
}

/// Handles bidirectional conversion between Markdown and NSAttributedString
class MarkdownConverter {

    // MARK: - Markdown → NSAttributedString

    /// Converts markdown text to an attributed string for rich text editing
    func attributedString(from markdown: String, textFont: UIFont, codeFont: UIFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        var inCodeBlock = false
        var codeBlockLines: [String] = []

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        for (index, line) in lines.enumerated() {
            let isLastLine = index == lines.count - 1

            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    let code = codeBlockLines.joined(separator: "\n")
                    let codeAttr = NSMutableAttributedString(string: code, attributes: [
                        .font: codeFont,
                        .backgroundColor: UIColor.secondaryLabel.withAlphaComponent(0.1),
                        .paragraphStyle: paragraphStyle,
                        .markdownBlockType: MarkdownBlockType.codeBlock.rawValue
                    ])
                    result.append(codeAttr)
                    if !isLastLine {
                        result.append(NSAttributedString(string: "\n"))
                    }
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
                appendHeader(to: result, text: String(line.dropFirst(6)), level: 6, scale: 1.1, weight: .semibold, textFont: textFont, isLastLine: isLastLine)
            } else if line.hasPrefix("#####") {
                appendHeader(to: result, text: String(line.dropFirst(5)), level: 5, scale: 1.15, weight: .semibold, textFont: textFont, isLastLine: isLastLine)
            } else if line.hasPrefix("####") {
                appendHeader(to: result, text: String(line.dropFirst(4)), level: 4, scale: 1.2, weight: .bold, textFont: textFont, isLastLine: isLastLine)
            } else if line.hasPrefix("###") {
                appendHeader(to: result, text: String(line.dropFirst(3)), level: 3, scale: 1.3, weight: .bold, textFont: textFont, isLastLine: isLastLine)
            } else if line.hasPrefix("##") {
                appendHeader(to: result, text: String(line.dropFirst(2)), level: 2, scale: 1.5, weight: .bold, textFont: textFont, isLastLine: isLastLine)
            } else if line.hasPrefix("#") {
                appendHeader(to: result, text: String(line.dropFirst(1)), level: 1, scale: 1.8, weight: .bold, textFont: textFont, isLastLine: isLastLine)
            } else if line.hasPrefix(">") {
                // Blockquote
                let text = line.dropFirst(1).trimmingCharacters(in: .whitespaces)
                let blockquoteStyle = NSMutableParagraphStyle()
                blockquoteStyle.firstLineHeadIndent = 12
                blockquoteStyle.headIndent = 12
                blockquoteStyle.lineSpacing = 4
                let attr = NSMutableAttributedString(string: text, attributes: [
                    .font: textFont,
                    .foregroundColor: UIColor.secondaryLabel,
                    .paragraphStyle: blockquoteStyle,
                    .markdownBlockType: MarkdownBlockType.blockquote.rawValue
                ])
                result.append(attr)
                if !isLastLine {
                    result.append(NSAttributedString(string: "\n"))
                }
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                // List item
                let prefix = String(line.prefix(2))
                let text = String(line.dropFirst(2))
                let listStyle = NSMutableParagraphStyle()
                listStyle.firstLineHeadIndent = 0
                listStyle.headIndent = 16
                listStyle.lineSpacing = 4

                let bulletAttr = NSMutableAttributedString(string: "• ", attributes: [
                    .font: textFont,
                    .paragraphStyle: listStyle,
                    .markdownBlockType: MarkdownBlockType.listItem.rawValue,
                    .markdownListPrefix: prefix
                ])
                result.append(bulletAttr)
                appendInlineMarkdown(to: result, text: text, textFont: textFont, isLastLine: isLastLine)
            } else if line.trimmingCharacters(in: .whitespaces) == "---" {
                let hrAttr = NSMutableAttributedString(string: "―――――――――――――――――――", attributes: [
                    .font: textFont,
                    .foregroundColor: UIColor.separator,
                    .markdownBlockType: MarkdownBlockType.horizontalRule.rawValue
                ])
                result.append(hrAttr)
                if !isLastLine {
                    result.append(NSAttributedString(string: "\n"))
                }
            } else if !line.isEmpty {
                appendInlineMarkdown(to: result, text: line, textFont: textFont, isLastLine: isLastLine)
            } else {
                result.append(NSAttributedString(string: "\n", attributes: [
                    .font: textFont,
                    .paragraphStyle: paragraphStyle
                ]))
            }
        }

        return result
    }

    private func appendHeader(to result: NSMutableAttributedString, text: String, level: Int, scale: CGFloat, weight: UIFont.Weight, textFont: UIFont, isLastLine: Bool) {
        let headerFont = UIFont.systemFont(ofSize: textFont.pointSize * scale, weight: weight)
        let headerStyle = NSMutableParagraphStyle()
        headerStyle.lineSpacing = 4
        headerStyle.paragraphSpacingBefore = 8
        let attr = NSMutableAttributedString(string: text.trimmingCharacters(in: .whitespaces), attributes: [
            .font: headerFont,
            .paragraphStyle: headerStyle,
            .markdownBlockType: MarkdownBlockType.header.rawValue,
            .markdownHeaderLevel: level
        ])
        result.append(attr)
        if !isLastLine {
            result.append(NSAttributedString(string: "\n"))
        }
    }

    private func appendInlineMarkdown(to result: NSMutableAttributedString, text: String, textFont: UIFont, isLastLine: Bool) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        // Try to parse inline markdown (bold, italic, code, links)
        if let attributed = try? NSAttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            let mutable = NSMutableAttributedString(attributedString: attributed)
            // Enumerate existing fonts and preserve traits while updating to base font size
            mutable.enumerateAttribute(.font, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
                if let existingFont = value as? UIFont {
                    let traits = existingFont.fontDescriptor.symbolicTraits
                    var newFont = textFont
                    if traits.contains(.traitBold) && traits.contains(.traitItalic) {
                        if let descriptor = textFont.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) {
                            newFont = UIFont(descriptor: descriptor, size: textFont.pointSize)
                        }
                    } else if traits.contains(.traitBold) {
                        if let descriptor = textFont.fontDescriptor.withSymbolicTraits(.traitBold) {
                            newFont = UIFont(descriptor: descriptor, size: textFont.pointSize)
                        }
                    } else if traits.contains(.traitItalic) {
                        if let descriptor = textFont.fontDescriptor.withSymbolicTraits(.traitItalic) {
                            newFont = UIFont(descriptor: descriptor, size: textFont.pointSize)
                        }
                    }
                    mutable.addAttribute(.font, value: newFont, range: range)
                } else {
                    mutable.addAttribute(.font, value: textFont, range: range)
                }
            }
            // Apply paragraph style
            mutable.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: mutable.length))
            result.append(mutable)
        } else {
            result.append(NSAttributedString(string: text, attributes: [
                .font: textFont,
                .paragraphStyle: paragraphStyle
            ]))
        }

        if !isLastLine {
            result.append(NSAttributedString(string: "\n", attributes: [
                .font: textFont,
                .paragraphStyle: paragraphStyle
            ]))
        }
    }

    // MARK: - NSAttributedString → Markdown

    /// Converts an attributed string back to markdown text
    func markdown(from attributedString: NSAttributedString) -> String {
        var result: [String] = []

        // Process line by line
        var currentIndex = 0
        let string = attributedString.string

        while currentIndex < string.count {
            let startIndex = string.index(string.startIndex, offsetBy: currentIndex)
            let lineEndIndex = string[startIndex...].firstIndex(of: "\n") ?? string.endIndex
            let lineRange = startIndex..<lineEndIndex

            let nsRange = NSRange(lineRange, in: string)
            let lineText = String(string[lineRange])

            if nsRange.length > 0 {
                let lineMarkdown = convertLineToMarkdown(attributedString: attributedString, range: nsRange, lineText: lineText)
                result.append(lineMarkdown)
            } else {
                result.append("")
            }

            if lineEndIndex < string.endIndex {
                currentIndex = string.distance(from: string.startIndex, to: lineEndIndex) + 1
            } else {
                break
            }
        }

        return result.joined(separator: "\n")
    }

    private func convertLineToMarkdown(attributedString: NSAttributedString, range: NSRange, lineText: String) -> String {
        // Check for block-level attributes
        var blockType: MarkdownBlockType = .paragraph
        var headerLevel: Int = 0
        var listPrefix: String = "- "

        attributedString.enumerateAttributes(in: range, options: []) { attrs, _, _ in
            if let type = attrs[.markdownBlockType] as? String,
               let parsed = MarkdownBlockType(rawValue: type) {
                blockType = parsed
            }
            if let level = attrs[.markdownHeaderLevel] as? Int {
                headerLevel = level
            }
            if let prefix = attrs[.markdownListPrefix] as? String {
                listPrefix = prefix
            }
        }

        switch blockType {
        case .header:
            let prefix = String(repeating: "#", count: headerLevel) + " "
            let content = convertInlineFormatting(attributedString: attributedString, range: range)
            return prefix + content

        case .codeBlock:
            // Code blocks are stored without the ``` markers, add them back
            return "```\n" + lineText + "\n```"

        case .blockquote:
            let content = convertInlineFormatting(attributedString: attributedString, range: range)
            return "> " + content

        case .listItem:
            // Remove the bullet point from the text and convert inline formatting
            let textWithoutBullet = lineText.hasPrefix("• ") ? String(lineText.dropFirst(2)) : lineText
            let bulletRange = NSRange(location: range.location + 2, length: max(0, range.length - 2))
            if bulletRange.length > 0 {
                let content = convertInlineFormatting(attributedString: attributedString, range: bulletRange)
                return listPrefix + content
            }
            return listPrefix + textWithoutBullet

        case .horizontalRule:
            return "---"

        case .paragraph:
            return convertInlineFormatting(attributedString: attributedString, range: range)
        }
    }

    private func convertInlineFormatting(attributedString: NSAttributedString, range: NSRange) -> String {
        guard range.length > 0, range.location + range.length <= attributedString.length else {
            return ""
        }

        var result = ""
        let string = attributedString.string
        let substring = (string as NSString).substring(with: range)

        // Track formatting runs
        var formattingRuns: [(range: NSRange, isBold: Bool, isItalic: Bool, isCode: Bool, linkURL: URL?)] = []

        attributedString.enumerateAttributes(in: range, options: []) { attrs, attrRange, _ in
            var isBold = false
            var isItalic = false
            var isCode = false
            var linkURL: URL?

            if let font = attrs[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                isBold = traits.contains(.traitBold)
                isItalic = traits.contains(.traitItalic)

                // Check if it's a monospace font (code)
                if font.fontName.lowercased().contains("mono") ||
                   font.fontName.lowercased().contains("courier") ||
                   font.fontName.lowercased().contains("menlo") ||
                   font.fontName.lowercased().contains("sf mono") {
                    isCode = true
                }
            }

            if let bgColor = attrs[.backgroundColor] as? UIColor {
                // Likely a code block/inline code
                var alpha: CGFloat = 0
                bgColor.getWhite(nil, alpha: &alpha)
                if alpha > 0 {
                    isCode = true
                }
            }

            if let link = attrs[.link] as? URL {
                linkURL = link
            } else if let link = attrs[.link] as? String, let url = URL(string: link) {
                linkURL = url
            }

            formattingRuns.append((attrRange, isBold, isItalic, isCode, linkURL))
        }

        // If no special formatting, return plain text
        if formattingRuns.isEmpty || formattingRuns.allSatisfy({ !$0.isBold && !$0.isItalic && !$0.isCode && $0.linkURL == nil }) {
            return substring
        }

        // Convert formatting runs to markdown
        for run in formattingRuns {
            let localRange = NSRange(location: run.range.location - range.location, length: run.range.length)
            guard localRange.location >= 0, localRange.location + localRange.length <= substring.count else { continue }

            let startIdx = substring.index(substring.startIndex, offsetBy: localRange.location)
            let endIdx = substring.index(startIdx, offsetBy: localRange.length)
            var text = String(substring[startIdx..<endIdx])

            if let url = run.linkURL {
                text = "[\(text)](\(url.absoluteString))"
            } else if run.isCode {
                text = "`\(text)`"
            } else {
                if run.isBold && run.isItalic {
                    text = "***\(text)***"
                } else if run.isBold {
                    text = "**\(text)**"
                } else if run.isItalic {
                    text = "*\(text)*"
                }
            }

            result += text
        }

        // If result is empty (all formatting was inline without changes), return original
        if result.isEmpty {
            return substring
        }

        return result
    }

    // MARK: - Formatting Helpers

    /// Applies bold formatting to the specified range
    func applyBold(to attributedString: NSMutableAttributedString, range: NSRange) {
        attributedString.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            if let font = value as? UIFont {
                if let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(.traitBold)) {
                    let newFont = UIFont(descriptor: descriptor, size: font.pointSize)
                    attributedString.addAttribute(.font, value: newFont, range: attrRange)
                }
            }
        }
    }

    /// Removes bold formatting from the specified range
    func removeBold(from attributedString: NSMutableAttributedString, range: NSRange) {
        attributedString.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            if let font = value as? UIFont {
                if let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.subtracting(.traitBold)) {
                    let newFont = UIFont(descriptor: descriptor, size: font.pointSize)
                    attributedString.addAttribute(.font, value: newFont, range: attrRange)
                }
            }
        }
    }

    /// Applies italic formatting to the specified range
    func applyItalic(to attributedString: NSMutableAttributedString, range: NSRange) {
        attributedString.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            if let font = value as? UIFont {
                if let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(.traitItalic)) {
                    let newFont = UIFont(descriptor: descriptor, size: font.pointSize)
                    attributedString.addAttribute(.font, value: newFont, range: attrRange)
                }
            }
        }
    }

    /// Removes italic formatting from the specified range
    func removeItalic(from attributedString: NSMutableAttributedString, range: NSRange) {
        attributedString.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            if let font = value as? UIFont {
                if let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.subtracting(.traitItalic)) {
                    let newFont = UIFont(descriptor: descriptor, size: font.pointSize)
                    attributedString.addAttribute(.font, value: newFont, range: attrRange)
                }
            }
        }
    }

    /// Checks if the range has bold formatting
    func isBold(in attributedString: NSAttributedString, range: NSRange) -> Bool {
        var hasBold = false
        attributedString.enumerateAttribute(.font, in: range, options: []) { value, _, stop in
            if let font = value as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    hasBold = true
                    stop.pointee = true
                }
            }
        }
        return hasBold
    }

    /// Checks if the range has italic formatting
    func isItalic(in attributedString: NSAttributedString, range: NSRange) -> Bool {
        var hasItalic = false
        attributedString.enumerateAttribute(.font, in: range, options: []) { value, _, stop in
            if let font = value as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                    hasItalic = true
                    stop.pointee = true
                }
            }
        }
        return hasItalic
    }
}

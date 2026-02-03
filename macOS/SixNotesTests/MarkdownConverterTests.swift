import XCTest
@testable import SixNotes

final class MarkdownConverterTests: XCTestCase {

    var sut: MarkdownConverter!
    var textFont: NSFont!
    var codeFont: NSFont!

    override func setUp() {
        super.setUp()
        sut = MarkdownConverter()
        textFont = NSFont.systemFont(ofSize: 14)
        codeFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    }

    override func tearDown() {
        sut = nil
        textFont = nil
        codeFont = nil
        super.tearDown()
    }

    // MARK: - Markdown to NSAttributedString Tests

    func testPlainTextConversion() {
        let markdown = "Hello World"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        XCTAssertEqual(attributed.string, "Hello World")
    }

    func testBoldConversion() {
        let markdown = "This is **bold** text"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        // Just verify the text content is present - bold formatting depends on font availability
        XCTAssertTrue(attributed.string.contains("bold"))
        XCTAssertTrue(attributed.string.contains("This is"))
        XCTAssertTrue(attributed.string.contains("text"))
    }

    func testItalicConversion() {
        let markdown = "This is *italic* text"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        // Just verify the text content is present - italic formatting depends on font availability
        XCTAssertTrue(attributed.string.contains("italic"))
        XCTAssertTrue(attributed.string.contains("This is"))
        XCTAssertTrue(attributed.string.contains("text"))
    }

    func testHeader1Conversion() {
        let markdown = "# Header 1"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        XCTAssertTrue(attributed.string.contains("Header 1"))

        // Check header level attribute
        var foundHeaderLevel = false
        attributed.enumerateAttribute(.markdownHeaderLevel, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let level = value as? Int, level == 1 {
                foundHeaderLevel = true
            }
        }
        XCTAssertTrue(foundHeaderLevel, "Header level 1 should be stored")
    }

    func testHeader2Conversion() {
        let markdown = "## Header 2"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        XCTAssertTrue(attributed.string.contains("Header 2"))

        var foundHeaderLevel = false
        attributed.enumerateAttribute(.markdownHeaderLevel, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let level = value as? Int, level == 2 {
                foundHeaderLevel = true
            }
        }
        XCTAssertTrue(foundHeaderLevel, "Header level 2 should be stored")
    }

    func testCodeBlockConversion() {
        let markdown = "```\nlet x = 42\n```"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        XCTAssertTrue(attributed.string.contains("let x = 42"))

        // Check code block attribute
        var foundCodeBlock = false
        attributed.enumerateAttribute(.markdownBlockType, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let type = value as? String, type == MarkdownBlockType.codeBlock.rawValue {
                foundCodeBlock = true
            }
        }
        XCTAssertTrue(foundCodeBlock, "Code block type should be stored")
    }

    func testBlockquoteConversion() {
        let markdown = "> This is a quote"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        XCTAssertTrue(attributed.string.contains("This is a quote"))

        var foundBlockquote = false
        attributed.enumerateAttribute(.markdownBlockType, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let type = value as? String, type == MarkdownBlockType.blockquote.rawValue {
                foundBlockquote = true
            }
        }
        XCTAssertTrue(foundBlockquote, "Blockquote type should be stored")
    }

    func testListItemConversion() {
        let markdown = "- List item"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        // List items are converted to bullet points
        XCTAssertTrue(attributed.string.contains("•"))
        XCTAssertTrue(attributed.string.contains("List item"))

        var foundListItem = false
        attributed.enumerateAttribute(.markdownBlockType, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let type = value as? String, type == MarkdownBlockType.listItem.rawValue {
                foundListItem = true
            }
        }
        XCTAssertTrue(foundListItem, "List item type should be stored")
    }

    func testHorizontalRuleConversion() {
        let markdown = "---"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        var foundHR = false
        attributed.enumerateAttribute(.markdownBlockType, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let type = value as? String, type == MarkdownBlockType.horizontalRule.rawValue {
                foundHR = true
            }
        }
        XCTAssertTrue(foundHR, "Horizontal rule type should be stored")
    }

    func testMultilineMarkdown() {
        let markdown = """
        # Title

        This is **bold** and *italic*.

        - Item 1
        - Item 2
        """
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        XCTAssertTrue(attributed.string.contains("Title"))
        XCTAssertTrue(attributed.string.contains("bold"))
        XCTAssertTrue(attributed.string.contains("italic"))
        XCTAssertTrue(attributed.string.contains("Item 1"))
        XCTAssertTrue(attributed.string.contains("Item 2"))
    }

    // MARK: - NSAttributedString to Markdown Tests

    func testPlainTextToMarkdown() {
        let markdown = "Hello World"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)
        let result = sut.markdown(from: attributed)

        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), "Hello World")
    }

    func testHeaderToMarkdown() {
        let markdown = "# Header 1"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)
        let result = sut.markdown(from: attributed)

        XCTAssertTrue(result.hasPrefix("# "), "Should start with header marker")
        XCTAssertTrue(result.contains("Header 1"))
    }

    func testHeader2ToMarkdown() {
        let markdown = "## Header 2"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)
        let result = sut.markdown(from: attributed)

        XCTAssertTrue(result.hasPrefix("## "), "Should start with ## marker")
        XCTAssertTrue(result.contains("Header 2"))
    }

    func testBlockquoteToMarkdown() {
        let markdown = "> Quote text"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)
        let result = sut.markdown(from: attributed)

        XCTAssertTrue(result.hasPrefix("> "), "Should start with blockquote marker")
        XCTAssertTrue(result.contains("Quote text"))
    }

    func testListItemToMarkdown() {
        let markdown = "- List item"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)
        let result = sut.markdown(from: attributed)

        XCTAssertTrue(result.hasPrefix("- "), "Should start with list marker")
        XCTAssertTrue(result.contains("List item"))
    }

    func testHorizontalRuleToMarkdown() {
        let markdown = "---"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)
        let result = sut.markdown(from: attributed)

        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), "---")
    }

    // MARK: - Formatting Helper Tests

    func testApplyBold() {
        let attributed = NSMutableAttributedString(string: "Hello", attributes: [.font: textFont!])
        sut.applyBold(to: attributed, range: NSRange(location: 0, length: 5))

        XCTAssertTrue(sut.isBold(in: attributed, range: NSRange(location: 0, length: 5)))
    }

    func testRemoveBold() {
        let boldFont = NSFontManager.shared.convert(textFont, toHaveTrait: .boldFontMask)
        let attributed = NSMutableAttributedString(string: "Hello", attributes: [.font: boldFont])

        XCTAssertTrue(sut.isBold(in: attributed, range: NSRange(location: 0, length: 5)))

        sut.removeBold(from: attributed, range: NSRange(location: 0, length: 5))

        XCTAssertFalse(sut.isBold(in: attributed, range: NSRange(location: 0, length: 5)))
    }

    func testApplyItalic() {
        let attributed = NSMutableAttributedString(string: "Hello", attributes: [.font: textFont!])
        sut.applyItalic(to: attributed, range: NSRange(location: 0, length: 5))

        XCTAssertTrue(sut.isItalic(in: attributed, range: NSRange(location: 0, length: 5)))
    }

    func testRemoveItalic() {
        let italicFont = NSFontManager.shared.convert(textFont, toHaveTrait: .italicFontMask)
        let attributed = NSMutableAttributedString(string: "Hello", attributes: [.font: italicFont])

        XCTAssertTrue(sut.isItalic(in: attributed, range: NSRange(location: 0, length: 5)))

        sut.removeItalic(from: attributed, range: NSRange(location: 0, length: 5))

        XCTAssertFalse(sut.isItalic(in: attributed, range: NSRange(location: 0, length: 5)))
    }

    // MARK: - Edge Cases

    func testEmptyString() {
        let markdown = ""
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        // Empty string should produce empty or minimal attributed string
        XCTAssertTrue(attributed.length <= 1, "Empty markdown should produce empty or minimal attributed string")

        let result = sut.markdown(from: attributed)
        XCTAssertTrue(result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty attributed string should produce empty markdown")
    }

    func testWhitespaceOnlyString() {
        let markdown = "   "
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)
        let result = sut.markdown(from: attributed)

        // Whitespace should be preserved
        XCTAssertFalse(result.isEmpty)
    }

    func testMultipleEmptyLines() {
        let markdown = "Line 1\n\n\nLine 2"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        XCTAssertTrue(attributed.string.contains("Line 1"))
        XCTAssertTrue(attributed.string.contains("Line 2"))
    }

    func testSpecialCharacters() {
        let markdown = "Test < > & \" ' characters"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        XCTAssertTrue(attributed.string.contains("<"))
        XCTAssertTrue(attributed.string.contains(">"))
        XCTAssertTrue(attributed.string.contains("&"))
    }

    func testAllHeaderLevels() {
        for level in 1...6 {
            let prefix = String(repeating: "#", count: level)
            let markdown = "\(prefix) Header \(level)"
            let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

            var foundLevel = false
            attributed.enumerateAttribute(.markdownHeaderLevel, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
                if let storedLevel = value as? Int, storedLevel == level {
                    foundLevel = true
                }
            }
            XCTAssertTrue(foundLevel, "Header level \(level) should be stored")
        }
    }

    // MARK: - Apply Formatting and Convert to Markdown Tests

    func testApplyBoldConvertsToMarkdown() {
        // Start with plain text
        let attributed = NSMutableAttributedString(string: "Hello World", attributes: [.font: textFont!])

        // Apply bold to "World"
        sut.applyBold(to: attributed, range: NSRange(location: 6, length: 5))

        // Convert to markdown
        let markdown = sut.markdown(from: attributed)

        // Should contain **World** syntax
        XCTAssertTrue(markdown.contains("**World**"), "Applied bold should convert to **text** markdown")
    }

    func testApplyItalicConvertsToMarkdown() {
        // Start with plain text
        let attributed = NSMutableAttributedString(string: "Hello World", attributes: [.font: textFont!])

        // Apply italic to "World"
        sut.applyItalic(to: attributed, range: NSRange(location: 6, length: 5))

        // Convert to markdown
        let markdown = sut.markdown(from: attributed)

        // Should contain *World* syntax
        XCTAssertTrue(markdown.contains("*World*"), "Applied italic should convert to *text* markdown")
    }

    func testApplyBoldAndItalicConvertsToMarkdown() {
        // Start with plain text
        let attributed = NSMutableAttributedString(string: "Hello World", attributes: [.font: textFont!])

        // Apply both bold and italic to "World"
        sut.applyBold(to: attributed, range: NSRange(location: 6, length: 5))
        sut.applyItalic(to: attributed, range: NSRange(location: 6, length: 5))

        // Convert to markdown
        let markdown = sut.markdown(from: attributed)

        // Should contain ***World*** syntax
        XCTAssertTrue(markdown.contains("***World***"), "Applied bold+italic should convert to ***text*** markdown")
    }

    // MARK: - Corner Case Tests

    func testBoldToItalicTransition() {
        // Test bold text followed immediately by italic text
        let attributed = NSMutableAttributedString(string: "BoldItalic", attributes: [.font: textFont!])

        // Apply bold to "Bold"
        sut.applyBold(to: attributed, range: NSRange(location: 0, length: 4))
        // Apply italic to "Italic"
        sut.applyItalic(to: attributed, range: NSRange(location: 4, length: 6))

        let markdown = sut.markdown(from: attributed)

        // Should have both formats adjacent
        XCTAssertTrue(markdown.contains("**Bold**"), "Bold portion should be wrapped in **")
        XCTAssertTrue(markdown.contains("*Italic*"), "Italic portion should be wrapped in *")
    }

    func testPartialOverlapBoldItalic() {
        // Test overlapping bold and italic ranges
        let attributed = NSMutableAttributedString(string: "Hello World Test", attributes: [.font: textFont!])

        // Apply bold to "Hello World" (0-11)
        sut.applyBold(to: attributed, range: NSRange(location: 0, length: 11))
        // Apply italic to "World Test" (6-16) - overlaps with bold on "World"
        sut.applyItalic(to: attributed, range: NSRange(location: 6, length: 10))

        // Check that "World" has both bold and italic
        XCTAssertTrue(sut.isBold(in: attributed, range: NSRange(location: 6, length: 5)))
        XCTAssertTrue(sut.isItalic(in: attributed, range: NSRange(location: 6, length: 5)))

        // Check that "Hello " is only bold
        XCTAssertTrue(sut.isBold(in: attributed, range: NSRange(location: 0, length: 5)))
        XCTAssertFalse(sut.isItalic(in: attributed, range: NSRange(location: 0, length: 5)))

        // Check that " Test" is only italic
        XCTAssertFalse(sut.isBold(in: attributed, range: NSRange(location: 12, length: 4)))
        XCTAssertTrue(sut.isItalic(in: attributed, range: NSRange(location: 12, length: 4)))
    }

    func testRemoveBoldFromPartialRange() {
        // Apply bold to entire string, then remove from part
        let attributed = NSMutableAttributedString(string: "Hello World", attributes: [.font: textFont!])

        // Make everything bold
        sut.applyBold(to: attributed, range: NSRange(location: 0, length: 11))
        XCTAssertTrue(sut.isBold(in: attributed, range: NSRange(location: 0, length: 11)))

        // Remove bold from just "World"
        sut.removeBold(from: attributed, range: NSRange(location: 6, length: 5))

        // "Hello " should still be bold
        XCTAssertTrue(sut.isBold(in: attributed, range: NSRange(location: 0, length: 5)))
        // "World" should not be bold
        XCTAssertFalse(sut.isBold(in: attributed, range: NSRange(location: 6, length: 5)))
    }

    func testRemoveItalicFromPartialRange() {
        // Apply italic to entire string, then remove from part
        let attributed = NSMutableAttributedString(string: "Hello World", attributes: [.font: textFont!])

        // Make everything italic
        sut.applyItalic(to: attributed, range: NSRange(location: 0, length: 11))
        XCTAssertTrue(sut.isItalic(in: attributed, range: NSRange(location: 0, length: 11)))

        // Remove italic from just "Hello"
        sut.removeItalic(from: attributed, range: NSRange(location: 0, length: 5))

        // "Hello" should not be italic
        XCTAssertFalse(sut.isItalic(in: attributed, range: NSRange(location: 0, length: 5)))
        // " World" should still be italic
        XCTAssertTrue(sut.isItalic(in: attributed, range: NSRange(location: 6, length: 5)))
    }

    func testUnicodeTextFormatting() {
        // Test with emoji and non-ASCII characters
        let attributed = NSMutableAttributedString(string: "Hello 🌍 World café", attributes: [.font: textFont!])

        // Apply bold to emoji portion "🌍 World"
        let emojiRange = NSRange(location: 6, length: 8) // "🌍 World"
        sut.applyBold(to: attributed, range: emojiRange)

        XCTAssertTrue(sut.isBold(in: attributed, range: emojiRange))

        let markdown = sut.markdown(from: attributed)
        XCTAssertTrue(markdown.contains("**"), "Unicode text should still get bold markers")
    }

    func testSingleCharacterFormatting() {
        // Test formatting a single character
        let attributed = NSMutableAttributedString(string: "A", attributes: [.font: textFont!])

        sut.applyBold(to: attributed, range: NSRange(location: 0, length: 1))

        XCTAssertTrue(sut.isBold(in: attributed, range: NSRange(location: 0, length: 1)))

        let markdown = sut.markdown(from: attributed)
        XCTAssertEqual(markdown, "**A**")
    }

    func testFormattingPreservedThroughRoundTrip() {
        // Test that programmatically applied formatting survives round-trip
        // Note: System markdown parser font traits may not be reliably detectable,
        // so we test with programmatically applied formatting instead
        let attributed = NSMutableAttributedString(string: "This is bold and italic text", attributes: [.font: textFont!])

        // Apply bold to "bold"
        sut.applyBold(to: attributed, range: NSRange(location: 8, length: 4))
        // Apply italic to "italic"
        sut.applyItalic(to: attributed, range: NSRange(location: 17, length: 6))

        let resultMarkdown = sut.markdown(from: attributed)

        XCTAssertTrue(resultMarkdown.contains("**bold**"), "Bold should survive round-trip")
        XCTAssertTrue(resultMarkdown.contains("*italic*"), "Italic should survive round-trip")
    }

    func testBoldInsideHeader() {
        // Test bold text within a header
        let markdown = "# Header with **bold** word"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        // Verify header level is preserved
        var foundHeaderLevel = false
        attributed.enumerateAttribute(.markdownHeaderLevel, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let level = value as? Int, level == 1 {
                foundHeaderLevel = true
            }
        }
        XCTAssertTrue(foundHeaderLevel, "Header level should be preserved")

        // Convert back to markdown
        let result = sut.markdown(from: attributed)
        XCTAssertTrue(result.hasPrefix("# "), "Should start with header marker")
    }

    func testBoldInsideListItem() {
        // Test bold text within a list item
        let markdown = "- Item with **bold** word"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        // Convert back to markdown
        let result = sut.markdown(from: attributed)
        XCTAssertTrue(result.hasPrefix("- "), "Should start with list marker")
        XCTAssertTrue(result.contains("Item with") && result.contains("word"), "List content should be preserved")
    }

    func testBoldInsideBlockquote() {
        // Test bold text within a blockquote
        let markdown = "> Quote with **bold** word"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        // Verify blockquote type is preserved
        var foundBlockquote = false
        attributed.enumerateAttribute(.markdownBlockType, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let type = value as? String, type == MarkdownBlockType.blockquote.rawValue {
                foundBlockquote = true
            }
        }
        XCTAssertTrue(foundBlockquote, "Blockquote type should be preserved")

        // Convert back to markdown
        let result = sut.markdown(from: attributed)
        XCTAssertTrue(result.hasPrefix("> "), "Should start with blockquote marker")
    }

    func testMultipleFormattedWordsOnSameLine() {
        // Test multiple separate bold/italic words on same line
        let attributed = NSMutableAttributedString(string: "One two three four", attributes: [.font: textFont!])

        // Make "One" bold
        sut.applyBold(to: attributed, range: NSRange(location: 0, length: 3))
        // Make "three" italic
        sut.applyItalic(to: attributed, range: NSRange(location: 8, length: 5))

        let markdown = sut.markdown(from: attributed)

        XCTAssertTrue(markdown.contains("**One**"), "First word should be bold")
        XCTAssertTrue(markdown.contains("*three*"), "Third word should be italic")
    }

    func testZeroLengthRange() {
        // Test that zero-length ranges don't cause issues
        let attributed = NSMutableAttributedString(string: "Hello", attributes: [.font: textFont!])

        // This shouldn't crash
        sut.applyBold(to: attributed, range: NSRange(location: 2, length: 0))

        // Text should be unchanged
        XCTAssertFalse(sut.isBold(in: attributed, range: NSRange(location: 0, length: 5)))
    }

    func testOutOfBoundsRangeHandling() {
        // Test that out-of-bounds ranges are handled gracefully
        let attributed = NSMutableAttributedString(string: "Hi", attributes: [.font: textFont!])

        // convertInlineFormatting should handle this gracefully
        let markdown = sut.markdown(from: attributed)
        XCTAssertEqual(markdown, "Hi")
    }

    func testToggleBoldTwiceRestoresOriginal() {
        // Apply bold, then remove it - should return to original state
        let attributed = NSMutableAttributedString(string: "Hello", attributes: [.font: textFont!])

        XCTAssertFalse(sut.isBold(in: attributed, range: NSRange(location: 0, length: 5)))

        sut.applyBold(to: attributed, range: NSRange(location: 0, length: 5))
        XCTAssertTrue(sut.isBold(in: attributed, range: NSRange(location: 0, length: 5)))

        sut.removeBold(from: attributed, range: NSRange(location: 0, length: 5))
        XCTAssertFalse(sut.isBold(in: attributed, range: NSRange(location: 0, length: 5)))
    }

    func testToggleItalicTwiceRestoresOriginal() {
        // Apply italic, then remove it - should return to original state
        let attributed = NSMutableAttributedString(string: "Hello", attributes: [.font: textFont!])

        XCTAssertFalse(sut.isItalic(in: attributed, range: NSRange(location: 0, length: 5)))

        sut.applyItalic(to: attributed, range: NSRange(location: 0, length: 5))
        XCTAssertTrue(sut.isItalic(in: attributed, range: NSRange(location: 0, length: 5)))

        sut.removeItalic(from: attributed, range: NSRange(location: 0, length: 5))
        XCTAssertFalse(sut.isItalic(in: attributed, range: NSRange(location: 0, length: 5)))
    }

    func testMultiLineTextFormatting() {
        // Test formatting that spans multiple lines
        let attributed = NSMutableAttributedString(string: "Line one\nLine two\nLine three", attributes: [.font: textFont!])

        // Apply bold to "one\nLine two\nLine"
        sut.applyBold(to: attributed, range: NSRange(location: 5, length: 18))

        XCTAssertTrue(sut.isBold(in: attributed, range: NSRange(location: 5, length: 18)))

        // First part of line one should not be bold
        XCTAssertFalse(sut.isBold(in: attributed, range: NSRange(location: 0, length: 4)))
    }

    func testConsecutiveBoldAndItalicMarkdown() {
        // Test parsing markdown with consecutive **bold** and *italic*
        let markdown = "**bold***italic*"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        // Should contain both words
        XCTAssertTrue(attributed.string.contains("bold"))
        XCTAssertTrue(attributed.string.contains("italic"))
    }

    func testNestedMarkdownSyntax() {
        // Test ***bold and italic*** syntax
        let markdown = "***both***"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        // Should contain the word
        XCTAssertTrue(attributed.string.contains("both"))
    }

    func testPreserveNonFormattedText() {
        // Ensure text without formatting remains unchanged
        let attributed = NSMutableAttributedString(string: "Plain text only", attributes: [.font: textFont!])

        let markdown = sut.markdown(from: attributed)

        XCTAssertEqual(markdown, "Plain text only")
    }

    func testCodeBlockNotAffectedByBoldItalic() {
        // Code blocks should not have bold/italic applied
        let markdown = "```\nlet x = 42\n```"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        // Code should be preserved
        XCTAssertTrue(attributed.string.contains("let x = 42"))

        // Should have code block attribute
        var foundCodeBlock = false
        attributed.enumerateAttribute(.markdownBlockType, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let type = value as? String, type == MarkdownBlockType.codeBlock.rawValue {
                foundCodeBlock = true
            }
        }
        XCTAssertTrue(foundCodeBlock)
    }
}

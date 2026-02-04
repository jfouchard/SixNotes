import XCTest
@testable import SixNotes

final class MarkdownConverterTests: XCTestCase {

    var sut: MarkdownConverter!
    var textFont: UIFont!
    var codeFont: UIFont!

    override func setUp() {
        super.setUp()
        sut = MarkdownConverter()
        textFont = UIFont.systemFont(ofSize: 14)
        codeFont = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
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

        XCTAssertTrue(attributed.string.contains("bold"))
        XCTAssertTrue(attributed.string.contains("This is"))
        XCTAssertTrue(attributed.string.contains("text"))
    }

    func testItalicConversion() {
        let markdown = "This is *italic* text"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        XCTAssertTrue(attributed.string.contains("italic"))
        XCTAssertTrue(attributed.string.contains("This is"))
        XCTAssertTrue(attributed.string.contains("text"))
    }

    func testHeader1Conversion() {
        let markdown = "# Header 1"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        XCTAssertTrue(attributed.string.contains("Header 1"))

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
        let markdown = "- Item 1"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        XCTAssertTrue(attributed.string.contains("Item 1"))
        XCTAssertTrue(attributed.string.contains("•"))

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

    func testMultiLineConversion() {
        let markdown = "Line 1\nLine 2\nLine 3"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        XCTAssertTrue(attributed.string.contains("Line 1"))
        XCTAssertTrue(attributed.string.contains("Line 2"))
        XCTAssertTrue(attributed.string.contains("Line 3"))
    }

    // MARK: - NSAttributedString to Markdown Tests

    func testPlainTextRoundTrip() {
        let markdown = "Hello World"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)
        let result = sut.markdown(from: attributed)

        XCTAssertEqual(result, "Hello World")
    }

    func testHeaderRoundTrip() {
        let markdown = "# Header 1"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)
        let result = sut.markdown(from: attributed)

        // The round trip should preserve the header format
        XCTAssertTrue(result.hasPrefix("# ") && result.contains("Header 1"))
    }

    func testBlockquoteRoundTrip() {
        let markdown = "> This is a quote"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)
        let result = sut.markdown(from: attributed)

        XCTAssertTrue(result.contains("> This is a quote"))
    }

    func testListItemRoundTrip() {
        let markdown = "- Item 1"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)
        let result = sut.markdown(from: attributed)

        XCTAssertTrue(result.contains("- Item 1"))
    }

    func testHorizontalRuleRoundTrip() {
        let markdown = "---"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)
        let result = sut.markdown(from: attributed)

        XCTAssertEqual(result, "---")
    }

    // MARK: - Empty/Edge Cases

    func testEmptyStringConversion() {
        let markdown = ""
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        // Empty markdown produces a single newline due to the loop handling
        XCTAssertTrue(attributed.string.isEmpty || attributed.string == "\n")
    }

    func testWhitespaceOnlyConversion() {
        let markdown = "   "
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        XCTAssertEqual(attributed.string, "   ")
    }

    func testEmptyLinesBetweenParagraphs() {
        let markdown = "First paragraph\n\nSecond paragraph"
        let attributed = sut.attributedString(from: markdown, textFont: textFont, codeFont: codeFont)

        XCTAssertTrue(attributed.string.contains("First paragraph"))
        XCTAssertTrue(attributed.string.contains("Second paragraph"))
    }

    // MARK: - Formatting Helper Tests

    func testApplyBold() {
        let attributed = NSMutableAttributedString(string: "Hello", attributes: [.font: textFont!])
        sut.applyBold(to: attributed, range: NSRange(location: 0, length: 5))

        var hasBold = false
        attributed.enumerateAttribute(.font, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let font = value as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    hasBold = true
                }
            }
        }
        XCTAssertTrue(hasBold, "Bold should be applied")
    }

    func testApplyItalic() {
        let attributed = NSMutableAttributedString(string: "Hello", attributes: [.font: textFont!])
        sut.applyItalic(to: attributed, range: NSRange(location: 0, length: 5))

        var hasItalic = false
        attributed.enumerateAttribute(.font, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let font = value as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                    hasItalic = true
                }
            }
        }
        XCTAssertTrue(hasItalic, "Italic should be applied")
    }

    func testIsBold() {
        let boldFont = UIFont.boldSystemFont(ofSize: 14)
        let attributed = NSAttributedString(string: "Bold", attributes: [.font: boldFont])

        XCTAssertTrue(sut.isBold(in: attributed, range: NSRange(location: 0, length: 4)))
    }

    func testIsItalic() {
        let italicFont = UIFont.italicSystemFont(ofSize: 14)
        let attributed = NSAttributedString(string: "Italic", attributes: [.font: italicFont])

        XCTAssertTrue(sut.isItalic(in: attributed, range: NSRange(location: 0, length: 6)))
    }

    func testRemoveBold() {
        let boldFont = UIFont.boldSystemFont(ofSize: 14)
        let attributed = NSMutableAttributedString(string: "Bold", attributes: [.font: boldFont])

        sut.removeBold(from: attributed, range: NSRange(location: 0, length: 4))

        var hasBold = false
        attributed.enumerateAttribute(.font, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let font = value as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    hasBold = true
                }
            }
        }
        XCTAssertFalse(hasBold, "Bold should be removed")
    }

    func testRemoveItalic() {
        let italicFont = UIFont.italicSystemFont(ofSize: 14)
        let attributed = NSMutableAttributedString(string: "Italic", attributes: [.font: italicFont])

        sut.removeItalic(from: attributed, range: NSRange(location: 0, length: 6))

        var hasItalic = false
        attributed.enumerateAttribute(.font, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let font = value as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                    hasItalic = true
                }
            }
        }
        XCTAssertFalse(hasItalic, "Italic should be removed")
    }
}

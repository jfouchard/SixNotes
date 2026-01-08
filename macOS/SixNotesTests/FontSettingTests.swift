import XCTest
import SwiftUI
@testable import SixNotes

final class FontSettingTests: XCTestCase {

    // MARK: - Initialization Tests

    func testFontSettingInitialization() {
        let fontSetting = FontSetting(name: "Menlo", size: 14)

        XCTAssertEqual(fontSetting.name, "Menlo")
        XCTAssertEqual(fontSetting.size, 14)
    }

    // MARK: - Default Values Tests (macOS specific defaults)

    func testDefaultTextFont() {
        let defaultText = FontSetting.defaultText

        XCTAssertEqual(defaultText.name, "System")
        XCTAssertEqual(defaultText.size, 14) // macOS uses 14pt
    }

    func testDefaultMonoFont() {
        let defaultMono = FontSetting.defaultMono

        XCTAssertEqual(defaultMono.name, "SF Mono")
        XCTAssertEqual(defaultMono.size, 13) // macOS uses 13pt
    }

    // MARK: - Available Fonts Tests

    func testAvailableFontsNotEmpty() {
        XCTAssertFalse(FontSetting.availableFonts.isEmpty)
    }

    func testAvailableFontsContainsSystem() {
        XCTAssertTrue(FontSetting.availableFonts.contains("System"))
    }

    func testAvailableFontsContainsNewYork() {
        XCTAssertTrue(FontSetting.availableFonts.contains("New York"))
    }

    func testAvailableFontsContainsMonoFonts() {
        let monoFonts = ["SF Mono", "Menlo", "Monaco", "Courier New"]
        for font in monoFonts {
            XCTAssertTrue(FontSetting.availableFonts.contains(font), "Missing mono font: \(font)")
        }
    }

    func testAvailableMonoFonts() {
        let expectedMonoFonts = ["SF Mono", "Menlo", "Monaco", "Courier New"]
        XCTAssertEqual(FontSetting.availableMonoFonts, expectedMonoFonts)
    }

    // MARK: - Codable Tests

    func testFontSettingEncodingAndDecoding() throws {
        let original = FontSetting(name: "Georgia", size: 18)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FontSetting.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.size, original.size)
    }

    func testFontSettingDecodingFromJSON() throws {
        let json = """
        {
            "name": "Palatino",
            "size": 20
        }
        """
        let data = json.data(using: .utf8)!

        let decoder = JSONDecoder()
        let fontSetting = try decoder.decode(FontSetting.self, from: data)

        XCTAssertEqual(fontSetting.name, "Palatino")
        XCTAssertEqual(fontSetting.size, 20)
    }

    // MARK: - Equatable Tests

    func testFontSettingEquality() {
        let font1 = FontSetting(name: "Menlo", size: 14)
        let font2 = FontSetting(name: "Menlo", size: 14)
        let font3 = FontSetting(name: "Monaco", size: 14)
        let font4 = FontSetting(name: "Menlo", size: 16)

        XCTAssertEqual(font1, font2)
        XCTAssertNotEqual(font1, font3)
        XCTAssertNotEqual(font1, font4)
    }

    // MARK: - NSFont Tests (macOS specific)

    func testSystemNSFont() {
        let fontSetting = FontSetting(name: "System", size: 16)
        let nsFont = fontSetting.nsFont

        XCTAssertEqual(nsFont.pointSize, 16)
    }

    func testNewYorkNSFont() {
        let fontSetting = FontSetting(name: "New York", size: 18)
        let nsFont = fontSetting.nsFont

        XCTAssertEqual(nsFont.pointSize, 18)
    }

    func testCustomNSFont() {
        let fontSetting = FontSetting(name: "Menlo", size: 14)
        let nsFont = fontSetting.nsFont

        XCTAssertEqual(nsFont.pointSize, 14)
    }

    func testInvalidFontFallsBackToMonospaced() {
        let fontSetting = FontSetting(name: "NonExistentFont", size: 14)
        let nsFont = fontSetting.nsFont

        // Should fall back to monospaced system font
        XCTAssertEqual(nsFont.pointSize, 14)
        XCTAssertNotNil(nsFont)
    }

    // MARK: - SwiftUI Font Tests

    func testSystemSwiftUIFont() {
        let fontSetting = FontSetting(name: "System", size: 16)
        let font = fontSetting.font

        // SwiftUI Font doesn't expose properties directly, just verify it doesn't crash
        XCTAssertNotNil(font)
    }

    func testNewYorkSwiftUIFont() {
        let fontSetting = FontSetting(name: "New York", size: 18)
        let font = fontSetting.font

        XCTAssertNotNil(font)
    }

    func testCustomSwiftUIFont() {
        let fontSetting = FontSetting(name: "Menlo", size: 14)
        let font = fontSetting.font

        XCTAssertNotNil(font)
    }
}

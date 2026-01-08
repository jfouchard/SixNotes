import SwiftUI

struct FontSetting: Codable, Equatable {
    var name: String
    var size: CGFloat

    static let availableFonts: [String] = {
        var fonts = ["System", "New York"]
        let monoFonts = ["SF Mono", "Menlo", "Monaco", "Courier New"]
        let additionalFonts = ["Helvetica Neue", "Georgia", "Palatino"]
        return fonts + monoFonts + additionalFonts
    }()

    static let availableMonoFonts: [String] = ["SF Mono", "Menlo", "Monaco", "Courier New"]

    static let defaultText = FontSetting(name: "System", size: 16)
    static let defaultMono = FontSetting(name: "SF Mono", size: 14)

    var font: Font {
        if name == "System" {
            return .system(size: size)
        } else if name == "New York" {
            return .system(size: size, design: .serif)
        } else {
            return .custom(name, size: size)
        }
    }

    var uiFont: UIFont {
        if name == "System" {
            return .systemFont(ofSize: size)
        } else if name == "New York" {
            return UIFont.systemFont(ofSize: size, weight: .regular, width: .standard)
        } else {
            return UIFont(name: name, size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }
}

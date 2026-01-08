import Foundation
import SwiftUI

struct Note: Codable, Identifiable {
    let id: Int
    var content: String
    var lastModified: Date
    var cursorPosition: Int

    init(id: Int, content: String = "", cursorPosition: Int = 0) {
        self.id = id
        self.content = content
        self.lastModified = Date()
        self.cursorPosition = cursorPosition
    }
}

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

    static let defaultText = FontSetting(name: "System", size: 14)
    static let defaultMono = FontSetting(name: "SF Mono", size: 13)

    var font: Font {
        if name == "System" {
            return .system(size: size)
        } else if name == "New York" {
            return .system(size: size, design: .serif)
        } else {
            return .custom(name, size: size)
        }
    }

    var nsFont: NSFont {
        if name == "System" {
            return NSFont.systemFont(ofSize: size)
        } else if name == "New York" {
            return NSFont(name: "New York", size: size) ?? NSFont.systemFont(ofSize: size)
        } else {
            return NSFont(name: name, size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }
}

class NotesManager: ObservableObject {
    @Published var notes: [Note]
    @Published var selectedNoteIndex: Int {
        didSet {
            UserDefaults.standard.set(selectedNoteIndex, forKey: selectedNoteKey)
        }
    }
    @Published var textFont: FontSetting {
        didSet {
            if let encoded = try? JSONEncoder().encode(textFont) {
                UserDefaults.standard.set(encoded, forKey: textFontKey)
            }
        }
    }
    @Published var codeFont: FontSetting {
        didSet {
            if let encoded = try? JSONEncoder().encode(codeFont) {
                UserDefaults.standard.set(encoded, forKey: codeFontKey)
            }
        }
    }

    private let saveKey = "SixNotes.notes"
    private let selectedNoteKey = "SixNotes.selectedNote"
    private let textFontKey = "SixNotes.textFont"
    private let codeFontKey = "SixNotes.codeFont"

    init() {
        // Load notes
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Note].self, from: data) {
            self.notes = decoded
        } else {
            self.notes = (0..<6).map { Note(id: $0) }
        }

        // Load selected note index
        let savedIndex = UserDefaults.standard.integer(forKey: selectedNoteKey)
        self.selectedNoteIndex = (0..<6).contains(savedIndex) ? savedIndex : 0

        // Load text font
        if let data = UserDefaults.standard.data(forKey: textFontKey),
           let font = try? JSONDecoder().decode(FontSetting.self, from: data) {
            self.textFont = font
        } else {
            self.textFont = .defaultText
        }

        // Load code font
        if let data = UserDefaults.standard.data(forKey: codeFontKey),
           let font = try? JSONDecoder().decode(FontSetting.self, from: data) {
            self.codeFont = font
        } else {
            self.codeFont = .defaultMono
        }
    }

    var currentNote: Binding<String> {
        Binding(
            get: { self.notes[self.selectedNoteIndex].content },
            set: { newValue in
                self.notes[self.selectedNoteIndex].content = newValue
                self.notes[self.selectedNoteIndex].lastModified = Date()
                self.save()
            }
        )
    }

    func selectNote(_ index: Int) {
        guard index >= 0 && index < 6 else { return }
        selectedNoteIndex = index
    }

    func hasContent(at index: Int) -> Bool {
        guard index >= 0 && index < notes.count else { return false }
        return !notes[index].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveCursorPosition(_ position: Int) {
        notes[selectedNoteIndex].cursorPosition = position
        save()
    }

    func getCursorPosition() -> Int {
        return notes[selectedNoteIndex].cursorPosition
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
}

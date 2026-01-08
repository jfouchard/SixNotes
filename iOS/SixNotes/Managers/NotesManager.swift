import Foundation
import SwiftUI

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

    func noteBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { self.notes[index].content },
            set: { newValue in
                self.notes[index].content = newValue
                self.notes[index].lastModified = Date()
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

    func saveCursorPosition(_ position: Int, for index: Int) {
        notes[index].cursorPosition = position
        save()
    }

    func getCursorPosition(for index: Int) -> Int {
        return notes[index].cursorPosition
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
}

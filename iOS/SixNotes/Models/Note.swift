import Foundation

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

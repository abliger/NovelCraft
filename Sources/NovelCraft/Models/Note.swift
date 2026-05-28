import Foundation
import SwiftData

@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var color: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    
    @Relationship(deleteRule: .nullify)
    var project: Project?
    
    init(
        title: String = "",
        content: String = "",
        color: String = "yellow",
        isPinned: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.color = color
        self.isPinned = isPinned
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

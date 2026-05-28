import Foundation
import SwiftData

@Model
final class Volume {
    @Attribute(.unique) var id: UUID
    var title: String
    var order: Int
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .nullify)
    var project: Project?
    
    @Relationship(deleteRule: .cascade, inverse: \Chapter.volume)
    var chapters: [Chapter]?
    
    init(title: String = "新卷", order: Int = 0) {
        self.id = UUID()
        self.title = title
        self.order = order
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var wordCount: Int {
        (chapters ?? []).reduce(0) { $0 + $1.wordCount }
    }
}

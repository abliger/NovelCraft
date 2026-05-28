import Foundation
import SwiftData

@Model
final class StoryScene {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var order: Int
    var createdAt: Date
    var updatedAt: Date
    var viewpointCharacter: String?
    var location: String?
    var timeOfDay: String?
    
    @Relationship(deleteRule: .nullify)
    var chapter: Chapter?
    
    init(
        title: String = "新场景",
        content: String = "",
        order: Int = 0,
        viewpointCharacter: String? = nil,
        location: String? = nil,
        timeOfDay: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.order = order
        self.createdAt = Date()
        self.updatedAt = Date()
        self.viewpointCharacter = viewpointCharacter
        self.location = location
        self.timeOfDay = timeOfDay
    }
    
    var wordCount: Int {
        content.split(whereSeparator: \.isWhitespace).count
    }
}

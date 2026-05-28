import Foundation
import SwiftData

@Model
final class WorldSetting {
    @Attribute(.unique) var id: UUID
    var category: String
    var title: String
    var content: String
    var order: Int
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .nullify)
    var project: Project?
    
    init(
        category: String = "未分类",
        title: String = "",
        content: String = "",
        order: Int = 0
    ) {
        self.id = UUID()
        self.category = category
        self.title = title
        self.content = content
        self.order = order
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

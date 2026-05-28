import Foundation
import SwiftData

@Model
final class OutlineNode {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var order: Int
    var createdAt: Date
    var updatedAt: Date
    var nodeType: String
    var x: Double
    var y: Double
    
    @Relationship(deleteRule: .nullify)
    var project: Project?
    
    @Relationship(deleteRule: .nullify)
    var parent: OutlineNode?
    
    @Relationship(deleteRule: .cascade, inverse: \OutlineNode.parent)
    var children: [OutlineNode]?
    
    init(
        title: String = "",
        content: String = "",
        order: Int = 0,
        nodeType: String = "card",
        x: Double = 0,
        y: Double = 0
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.order = order
        self.nodeType = nodeType
        self.x = x
        self.y = y
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

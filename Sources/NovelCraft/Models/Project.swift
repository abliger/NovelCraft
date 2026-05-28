import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var summary: String
    var coverImageData: Data?
    var createdAt: Date
    var updatedAt: Date
    var targetWordCount: Int
    var dailyWordGoal: Int
    
    @Relationship(deleteRule: .cascade, inverse: \Volume.project)
    var volumes: [Volume]?
    
    @Relationship(deleteRule: .cascade, inverse: \Character.project)
    var characters: [Character]?
    
    @Relationship(deleteRule: .cascade, inverse: \WorldSetting.project)
    var worldSettings: [WorldSetting]?
    
    @Relationship(deleteRule: .cascade, inverse: \OutlineNode.project)
    var outlineNodes: [OutlineNode]?
    
    @Relationship(deleteRule: .cascade, inverse: \Note.project)
    var notes: [Note]?
    
    init(
        title: String = "未命名小说",
        author: String = "",
        summary: String = "",
        coverImageData: Data? = nil,
        targetWordCount: Int = 50000,
        dailyWordGoal: Int = 2000
    ) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.summary = summary
        self.coverImageData = coverImageData
        self.createdAt = Date()
        self.updatedAt = Date()
        self.targetWordCount = targetWordCount
        self.dailyWordGoal = dailyWordGoal
    }
    
    var totalWordCount: Int {
        (volumes ?? []).reduce(0) { $0 + $1.wordCount }
    }
    
    var progressPercentage: Double {
        guard targetWordCount > 0 else { return 0 }
        return min(Double(totalWordCount) / Double(targetWordCount), 1.0)
    }
}

import Foundation
import SwiftData

enum ChapterStatus: String, Codable, CaseIterable {
    case draft = "草稿"
    case revising = "修订中"
    case completed = "已完成"
    case archived = "已归档"
}

@Model
final class Chapter {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var status: String
    var order: Int
    var createdAt: Date
    var updatedAt: Date
    var synopsis: String
    
    @Relationship(deleteRule: .nullify)
    var volume: Volume?
    
    @Relationship(deleteRule: .cascade, inverse: \StoryScene.chapter)
    var scenes: [StoryScene]?
    
    init(
        title: String = "新章节",
        content: String = "",
        status: ChapterStatus = .draft,
        order: Int = 0,
        synopsis: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.status = status.rawValue
        self.order = order
        self.createdAt = Date()
        self.updatedAt = Date()
        self.synopsis = synopsis
    }
    
    var chapterStatus: ChapterStatus {
        get { ChapterStatus(rawValue: status) ?? .draft }
        set { status = newValue.rawValue }
    }
    
    var wordCount: Int {
        content.split(whereSeparator: \.isWhitespace).count
    }
    
    var characterCount: Int {
        content.count
    }
}

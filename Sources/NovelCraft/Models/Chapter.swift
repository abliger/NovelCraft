import Foundation
import SwiftData

/// 章节状态枚举，用于标识章节的写作进度。
/// UI 显示请使用 `displayName`，rawValue 仅用于持久化，不可更改。
enum ChapterStatus: String, Codable, CaseIterable {
    case draft = "draft"
    case revising = "revising"
    case completed = "completed"
    case archived = "archived"
    
    /// 中文显示名称
    var displayName: String {
        switch self {
        case .draft: return "草稿"
        case .revising: return "修订中"
        case .completed: return "已完成"
        case .archived: return "已归档"
        }
    }
}

/// 章节实体，包含正文内容、状态、摘要及关联的场景列表。
@Model
final class Chapter {
    @Attribute(.unique) var id: UUID
    
    /// 章节标题
    var title: String
    /// 章节正文（Markdown 格式）
    var content: String
    /// 章节状态（直接持久化枚举）
    var chapterStatus: ChapterStatus
    /// 在所属卷中的排序序号
    var order: Int
    /// 创建时间
    var createdAt: Date
    /// 最后更新时间
    var updatedAt: Date
    /// 章节摘要/梗概
    var synopsis: String
    
    /// 所属卷（反向关系）
    @Relationship(deleteRule: .nullify)
    var volume: Volume?
    
    /// 关联的场景列表（级联删除）
    @Relationship(deleteRule: .cascade, inverse: \StoryScene.chapter)
    var scenes: [StoryScene]?
    
    init(
        title: String = "新章节",
        content: String = "",
        chapterStatus: ChapterStatus = .draft,
        order: Int = 0,
        synopsis: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.chapterStatus = chapterStatus
        self.order = order
        self.createdAt = Date()
        self.updatedAt = Date()
        self.synopsis = synopsis
    }
    
    /// 计算正文的字数（按字符计数，适合中文）
    var wordCount: Int {
        content.count
    }
    
    /// 计算正文的字符总数（含空格与标点）
    var characterCount: Int {
        content.count
    }
}

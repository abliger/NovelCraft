import Foundation
import SwiftData
import SwiftUI

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
    
    /// 状态对应的标识颜色
    var color: Color {
        switch self {
        case .draft: return .gray
        case .revising: return .orange
        case .completed: return .green
        case .archived: return .blue
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
    @Attribute(.externalStorage)
    var content: String
    /// 章节状态原始值（String 存储，避免 SwiftData 对 Codable 枚举的兼容性问题）
    // 索引由 SwiftData 自动管理
    var chapterStatusRaw: String
    /// 章节状态（计算属性，自动转换）
    var chapterStatus: ChapterStatus {
        get { ChapterStatus(rawValue: chapterStatusRaw) ?? .draft }
        set { chapterStatusRaw = newValue.rawValue }
    }
    /// 在所属卷中的排序序号
    // 索引由 SwiftData 自动管理
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
    var scenes: [StoryScene] = []
    
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
        self.chapterStatusRaw = chapterStatus.rawValue
        self.order = order
        self.createdAt = Date()
        self.updatedAt = Date()
        self.synopsis = synopsis
    }
    
    /// 计算正文的字数（过滤空格、换行与常见标点，适合中文写作统计）
    var wordCount: Int {
        let whitespaceAndPunctuation = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        return content.unicodeScalars.filter { !whitespaceAndPunctuation.contains($0) }.count
    }
    
    /// 计算正文的字符总数（含空格与标点）
    var characterCount: Int {
        content.count
    }
}

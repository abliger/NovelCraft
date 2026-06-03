import Foundation
import SwiftData

/// 小说项目实体，代表一部小说的顶层容器，包含卷、角色、世界观、大纲节点与便签等关联数据。
@Model
final class Project {
    @Attribute(.unique) var id: UUID
    
    /// 小说标题（必填）
    var title: String
    /// 作者名称
    var author: String
    /// 小说简介
    var summary: String
    /// 项目存储路径（包含项目名称的完整目录路径）
    // 索引由 SwiftData 自动管理
    var storagePath: String
    /// 整本书的大纲
    @Attribute(.externalStorage)
    var bookOutline: String
    /// 创建时间
    var createdAt: Date
    /// 最后更新时间
    var updatedAt: Date
    /// 目标总字数
    var targetWordCount: Int
    /// 每日写作目标字数
    var dailyWordGoal: Int
    
    /// 关联的卷列表（级联删除）
    @Relationship(deleteRule: .cascade, inverse: \Volume.project)
    var volumes: [Volume] = []
    
    /// 关联的角色列表（级联删除）
    @Relationship(deleteRule: .cascade, inverse: \Character.project)
    var characters: [Character] = []
    
    /// 关联的世界观设定列表（级联删除）
    @Relationship(deleteRule: .cascade, inverse: \WorldSetting.project)
    var worldSettings: [WorldSetting] = []
    
    /// 关联的大纲节点列表（级联删除）
    @Relationship(deleteRule: .cascade, inverse: \OutlineNode.project)
    var outlineNodes: [OutlineNode] = []
    
    /// 关联的便签列表（级联删除）
    @Relationship(deleteRule: .cascade, inverse: \Note.project)
    var notes: [Note] = []
    
    /// 关联的电子表格工作表列表（级联删除）
    @Relationship(deleteRule: .cascade, inverse: \SpreadsheetSheet.project)
    var spreadsheetSheets: [SpreadsheetSheet] = []
    
    /// 关联的待办事项列表（级联删除）
    @Relationship(deleteRule: .cascade, inverse: \TodoItem.project)
    var todoItems: [TodoItem] = []
    
    init(
        title: String,
        author: String = "",
        summary: String = "",
        storagePath: String,
        bookOutline: String = "",
        targetWordCount: Int = 50000,
        dailyWordGoal: Int = 2000
    ) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.summary = summary
        self.storagePath = storagePath
        self.bookOutline = bookOutline
        self.createdAt = Date()
        self.updatedAt = Date()
        self.targetWordCount = targetWordCount
        self.dailyWordGoal = dailyWordGoal
    }
    
    /// 计算当前项目下所有卷的总字数
    var totalWordCount: Int {
        volumes.reduce(0) { $0 + $1.wordCount }
    }
    
    /// 计算当前字数占目标字数的百分比（上限为 1.0）
    var progressPercentage: Double {
        guard targetWordCount > 0 else { return 0 }
        return min(Double(totalWordCount) / Double(targetWordCount), 1.0)
    }
}

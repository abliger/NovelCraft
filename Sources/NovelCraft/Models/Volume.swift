import Foundation
import SwiftData

/// 卷实体，用于组织小说中的多个章节。
@Model
final class Volume {
    @Attribute(.unique) var id: UUID
    
    /// 卷标题
    var title: String
    /// 在所属项目中的排序序号
    var order: Int
    /// 创建时间
    var createdAt: Date
    /// 最后更新时间
    var updatedAt: Date
    
    /// 所属项目（反向关系）
    @Relationship(deleteRule: .nullify)
    var project: Project?
    
    /// 关联的章节列表（级联删除）
    @Relationship(deleteRule: .cascade, inverse: \Chapter.volume)
    var chapters: [Chapter]?
    
    init(title: String = "新卷", order: Int = 0) {
        self.id = UUID()
        self.title = title
        self.order = order
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// 计算当前卷下所有章节的总字数（字符数）
    var wordCount: Int {
        (chapters ?? []).reduce(0) { $0 + $1.wordCount }
    }
}

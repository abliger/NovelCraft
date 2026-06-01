import Foundation
import SwiftData

/// 世界观设定实体，用于存储小说的各类设定（地理、历史、文化、魔法/科技等）。
@Model
final class WorldSetting {
    @Attribute(.unique) var id: UUID
    
    /// 设定分类
    // 索引由 SwiftData 自动管理
    var category: String
    /// 设定标题
    var title: String
    /// 设定详细内容
    @Attribute(.externalStorage)
    var content: String
    /// 在项目中的排序序号
    // 索引由 SwiftData 自动管理
    var order: Int
    /// 创建时间
    var createdAt: Date
    /// 最后更新时间
    var updatedAt: Date
    
    /// 所属项目（反向关系）
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

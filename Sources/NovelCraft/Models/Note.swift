import Foundation
import SwiftData

/// 便签实体，用于记录与项目相关的简短笔记，支持颜色标识与置顶。
@Model
final class Note {
    @Attribute(.unique) var id: UUID
    
    /// 便签标题
    var title: String
    /// 便签内容
    var content: String
    /// 颜色标识名称（仅接受预定义值）
    var color: String {
        didSet {
            if !Note.validColors.contains(color) {
                color = "yellow"
            }
        }
    }
    /// 创建时间
    var createdAt: Date
    /// 最后更新时间
    var updatedAt: Date
    /// 是否置顶
    var isPinned: Bool
    
    /// 所属项目（反向关系）
    @Relationship(deleteRule: .nullify)
    var project: Project?
    
    /// 预定义的有效颜色集合
    static let validColors: Set<String> = ["yellow", "red", "blue", "green", "purple", "orange"]
    
    init(
        title: String = "",
        content: String = "",
        color: String = "yellow",
        isPinned: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.color = Note.validColors.contains(color) ? color : "yellow"
        self.isPinned = isPinned
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

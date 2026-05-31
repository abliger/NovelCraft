import Foundation
import SwiftData

/// 场景实体，对应章节内的一个具体场景，可记录视角角色、地点与时间等信息。
@Model
final class StoryScene {
    @Attribute(.unique) var id: UUID
    
    /// 场景标题
    var title: String
    /// 场景正文内容
    var content: String
    /// 在所属章节中的排序序号
    var order: Int
    /// 创建时间
    var createdAt: Date
    /// 最后更新时间
    var updatedAt: Date
    /// 视角角色（可选）
    @Relationship(deleteRule: .nullify)
    var viewpointCharacter: Character?
    /// 场景地点（可选）
    var location: String?
    /// 场景发生的时间描述（可选）
    var timeOfDay: String?
    
    /// 所属章节（反向关系）
    @Relationship(deleteRule: .nullify)
    var chapter: Chapter?
    
    init(
        title: String = "新场景",
        content: String = "",
        order: Int = 0,
        viewpointCharacter: Character? = nil,
        location: String? = nil,
        timeOfDay: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.order = order
        self.createdAt = Date()
        self.updatedAt = Date()
        self.viewpointCharacter = viewpointCharacter
        self.location = location
        self.timeOfDay = timeOfDay
    }
    
    /// 计算场景正文的字数（字符数）
    var wordCount: Int {
        content.count
    }
}

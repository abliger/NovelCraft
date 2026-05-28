import Foundation
import SwiftData

/// 角色实体，用于存储小说中角色的详细设定信息。
@Model
final class Character {
    @Attribute(.unique) var id: UUID
    
    /// 角色姓名
    var name: String
    /// 角色别名/绰号
    var aliases: String
    /// 性别
    var gender: String
    /// 年龄描述
    var age: String
    /// 外貌特征
    var appearance: String
    /// 性格描述
    var personality: String
    /// 背景故事
    var background: String
    /// 目标与动机
    var goals: String
    /// 与其他角色的关系
    var relationships: String
    /// 备注
    var notes: String
    /// 头像二进制数据（可选）
    var avatarData: Data?
    /// 创建时间
    var createdAt: Date
    /// 最后更新时间
    var updatedAt: Date
    /// 在项目中的排序序号
    var order: Int
    
    /// 所属项目（反向关系）
    @Relationship(deleteRule: .nullify)
    var project: Project?
    
    init(
        name: String = "",
        aliases: String = "",
        gender: String = "",
        age: String = "",
        appearance: String = "",
        personality: String = "",
        background: String = "",
        goals: String = "",
        relationships: String = "",
        notes: String = "",
        order: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.aliases = aliases
        self.gender = gender
        self.age = age
        self.appearance = appearance
        self.personality = personality
        self.background = background
        self.goals = goals
        self.relationships = relationships
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.order = order
    }
}

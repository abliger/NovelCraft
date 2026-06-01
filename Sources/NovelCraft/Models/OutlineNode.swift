import Foundation
import SwiftData

/// 大纲节点实体，支持树形结构（父子关系）及二维坐标，用于组织小说大纲。
@Model
final class OutlineNode {
    @Attribute(.unique) var id: UUID
    
    /// 节点标题
    var title: String
    /// 节点内容描述
    @Attribute(.externalStorage)
    var content: String
    /// 在同级节点中的排序序号
    // 索引由 SwiftData 自动管理
    var order: Int
    /// 创建时间
    var createdAt: Date
    /// 最后更新时间
    var updatedAt: Date
    /// 节点类型（如 card / chapter / plot / arc）
    // 索引由 SwiftData 自动管理
    var nodeType: String
    /// 在画布中的 X 坐标
    var x: Double
    /// 在画布中的 Y 坐标
    var y: Double
    
    /// 所属项目（反向关系）
    @Relationship(deleteRule: .nullify)
    var project: Project?
    
    /// 父节点（反向关系，由 children 的 inverse 自动维护）
    @Relationship(deleteRule: .nullify)
    var parent: OutlineNode?
    
    /// 子节点列表（级联删除）
    @Relationship(deleteRule: .cascade, inverse: \OutlineNode.parent)
    var children: [OutlineNode] = []
    
    init(
        title: String = "",
        content: String = "",
        order: Int = 0,
        nodeType: String = "card",
        x: Double = 0,
        y: Double = 0,
        parent: OutlineNode? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.order = order
        self.nodeType = nodeType
        self.x = x
        self.y = y
        self.parent = parent
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

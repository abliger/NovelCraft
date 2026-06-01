import Foundation
import SwiftData

/// 待办事项模型，用于项目级任务管理。
@Model
final class TodoItem {
    @Attribute(.unique) var id: UUID
    /// 待办标题
    var title: String
    /// 是否已完成
    // 索引由 SwiftData 自动管理
    var isCompleted: Bool
    /// 所属项目（反向关系，由 todoItems 的 inverse 自动维护）
    @Relationship(deleteRule: .nullify)
    var project: Project?
    /// 排序顺序
    // 索引由 SwiftData 自动管理
    var order: Int
    /// 创建时间
    var createdAt: Date
    /// 完成时间
    var completedAt: Date?
    /// 所属项目 ID（兼容旧数据，新代码应使用 project 关系）
    var projectID: UUID
    
    init(title: String, project: Project? = nil, order: Int = 0) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.project = project
        self.projectID = project?.id ?? UUID()
        self.order = order
        self.createdAt = Date()
        self.completedAt = nil
    }
    
    /// 切换完成状态，自动维护 completedAt
    func toggleCompleted() {
        isCompleted.toggle()
        completedAt = isCompleted ? Date() : nil
    }
}

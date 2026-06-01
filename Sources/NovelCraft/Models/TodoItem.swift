import Foundation
import SwiftData

/// 待办事项模型，用于项目级任务管理。
@Model
final class TodoItem {
    @Attribute(.unique) var id: UUID
    /// 待办标题
    var title: String
    /// 是否已完成
    var isCompleted: Bool
    /// 所属项目 ID
    var projectID: UUID
    /// 排序顺序
    var order: Int
    /// 创建时间
    var createdAt: Date
    /// 完成时间
    var completedAt: Date?
    
    init(title: String, projectID: UUID, order: Int = 0) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.projectID = projectID
        self.order = order
        self.createdAt = Date()
        self.completedAt = nil
    }
}

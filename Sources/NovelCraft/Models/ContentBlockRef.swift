import Foundation
import SwiftData

/// 内容块引用关系类型
enum RefType: String, Codable, CaseIterable {
    case ref = "ref"       // 块引用 (( ))
    case embed = "embed"   // 块嵌入 {{ }}
    
    var displayName: String {
        switch self {
        case .ref: return "引用"
        case .embed: return "嵌入"
        }
    }
}

/// 内容块引用记录，用于实现双向链接。
///
/// 当章节、便签等内容中包含 `((目标ID "锚文本"))` 或 `{{目标ID}}` 语法时，
/// 保存后会自动解析并生成或更新此模型的记录。
@Model
final class ContentBlockRef {
    @Attribute(.unique) var id: UUID
    /// 引用方的内容块 ID（如章节 ID）
    var sourceBlockID: UUID
    /// 被引用方的内容块 ID
    var targetBlockID: UUID
    /// 锚文本（用户自定义的显示文本，可为空）
    var anchorText: String
    /// 引用类型：ref / embed
    var refType: String
    /// 创建时间
    var createdAt: Date
    
    init(sourceBlockID: UUID, targetBlockID: UUID, anchorText: String = "", refType: String = RefType.ref.rawValue) {
        self.id = UUID()
        self.sourceBlockID = sourceBlockID
        self.targetBlockID = targetBlockID
        self.anchorText = anchorText
        self.refType = refType
        self.createdAt = Date()
    }
    
    /// 引用类型枚举值
    var refTypeEnum: RefType {
        RefType(rawValue: refType) ?? .ref
    }
}

import Foundation
import SwiftData

/// 电子表格单元格，属于某个工作表，支持内容编辑与双向链接。
@Model
final class SpreadsheetCell {
    @Attribute(.unique) var id: UUID

    /// 所在行索引（从 0 开始）
    // 索引由 SwiftData 自动管理
    var row: Int
    /// 所在列索引（从 0 开始）
    // 索引由 SwiftData 自动管理
    var column: Int
    /// 单元格内容（支持 Markdown 与双向链接语法）
    @Attribute(.externalStorage)
    var content: String

    /// 所属工作表（反向关系，由 cells 的 inverse 自动维护）
    @Relationship(deleteRule: .nullify)
    var sheet: SpreadsheetSheet?

    init(
        row: Int,
        column: Int,
        content: String = ""
    ) {
        self.id = UUID()
        self.row = row
        self.column = column
        self.content = content
    }

    /// 列标题字母（A, B, C...）
    static func columnLetter(_ index: Int) -> String {
        var result = ""
        var n = index + 1
        while n > 0 {
            n -= 1
            let scalarValue = 65 + (n % 26)
            if let scalar = UnicodeScalar(scalarValue) {
                result = String(scalar) + result
            }
            n /= 26
        }
        return result
    }

    /// 单元格坐标标识（如 A1、B2）
    var coordinate: String {
        "\(SpreadsheetCell.columnLetter(column))\(row + 1)"
    }
}

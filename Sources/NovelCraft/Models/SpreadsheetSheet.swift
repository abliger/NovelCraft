import Foundation
import SwiftData

/// 电子表格工作表，属于某个项目，包含二维单元格网格。
@Model
final class SpreadsheetSheet {
    @Attribute(.unique) var id: UUID

    /// 工作表标题
    var title: String
    /// 行数
    // 索引由 SwiftData 自动管理
    var rowCount: Int
    /// 列数
    // 索引由 SwiftData 自动管理
    var columnCount: Int
    /// 创建时间
    var createdAt: Date
    /// 最后更新时间
    var updatedAt: Date

    /// 关联的单元格列表（级联删除）
    @Relationship(deleteRule: .cascade, inverse: \SpreadsheetCell.sheet)
    var cells: [SpreadsheetCell] = []

    /// 所属项目（反向关系）
    @Relationship(deleteRule: .nullify)
    var project: Project?

    init(
        title: String = "新表格",
        rowCount: Int = 15,
        columnCount: Int = 8
    ) {
        self.id = UUID()
        self.title = title
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 为当前工作表创建所有单元格（空内容）。
    func initializeCells(context: ModelContext) {
        for r in 0..<rowCount {
            for c in 0..<columnCount {
                let cell = SpreadsheetCell(row: r, column: c)
                cell.sheet = self
                context.insert(cell)
            }
        }
    }

    /// 在当前工作表中追加一行空单元格。
    func appendRow(context: ModelContext) {
        let newRow = rowCount
        for c in 0..<columnCount {
            let cell = SpreadsheetCell(row: newRow, column: c)
            cell.sheet = self
            context.insert(cell)
        }
        rowCount += 1
    }

    /// 在当前工作表中追加一列空单元格。
    func appendColumn(context: ModelContext) {
        let newCol = columnCount
        for r in 0..<rowCount {
            let cell = SpreadsheetCell(row: r, column: newCol)
            cell.sheet = self
            context.insert(cell)
        }
        columnCount += 1
    }

    /// 删除指定行及其所有单元格，并重新排列下方行的索引。
    func deleteRow(at row: Int, context: ModelContext) {
        guard row >= 0, row < rowCount else { return }
        // 删除目标行的所有单元格
        for cell in cells where cell.row == row {
            context.delete(cell)
        }
        // 下方行索引上移
        for cell in cells where cell.row > row {
            cell.row -= 1
        }
        rowCount -= 1
    }

    /// 删除指定列及其所有单元格，并重新排列右侧列的索引。
    func deleteColumn(at column: Int, context: ModelContext) {
        guard column >= 0, column < columnCount else { return }
        // 删除目标列的所有单元格
        for cell in cells where cell.column == column {
            context.delete(cell)
        }
        // 右侧列索引左移
        for cell in cells where cell.column > column {
            cell.column -= 1
        }
        columnCount -= 1
    }
}

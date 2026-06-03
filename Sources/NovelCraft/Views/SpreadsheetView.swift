import SwiftUI
import SwiftData

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 电子表格视图，以二维网格形式展示工作表中的单元格。
/// 支持点击编辑、行列选中、区域拖动选择以及复制粘贴。
struct SpreadsheetView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project

    @Query private var sheets: [SpreadsheetSheet]
    @State private var cells: [SpreadsheetCell] = []
    @State private var cellsByRowCol: [Int: [Int: SpreadsheetCell]] = [:]

    @State private var selectedSheet: SpreadsheetSheet?
    /// 当前正在编辑的单元格
    @State private var editingCell: SpreadsheetCell?
    /// 编辑中的临时文本
    @State private var editText: String = ""
    /// 控制当前 TextField 是否获得焦点
    @FocusState private var isCellFocused: Bool

    /// 选中区域起始坐标
    @State private var selectionStart: (row: Int, col: Int)? = nil
    /// 选中区域结束坐标
    @State private var selectionEnd: (row: Int, col: Int)? = nil
    /// 是否正在拖动选择
    @State private var isDragging = false
    /// 应用内部剪贴板，保存最近一次复制的 TSV 内容
    @State private var clipboardTsv: String = ""

    #if os(macOS)
    @State private var keyMonitor: Any? = nil
    #endif

    init(project: Project) {
        self.project = project
        let projectID = project.id
        _sheets = Query(
            filter: #Predicate<SpreadsheetSheet> { sheet in
                sheet.project?.id == projectID
            },
            sort: \.createdAt
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetTabBar
            Divider()
            spreadsheetGrid
            Divider()
            bottomToolbar
        }
        .onAppear {
            #if os(macOS)
            setupKeyMonitor()
            #endif
            if selectedSheet == nil, let first = sheets.first {
                selectedSheet = first
            }
            loadCells()
        }
        .onDisappear {
            #if os(macOS)
            removeKeyMonitor()
            #endif
        }
        .onChange(of: sheets) { _, newSheets in
            if selectedSheet == nil, let first = newSheets.first {
                selectedSheet = first
            }
        }
        .onChange(of: selectedSheet) { _, _ in
            loadCells()
        }
    }

    // MARK: - 子视图

    private var sheetTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(sheets) { sheet in
                    Button {
                        finishEditing()
                        withAnimation {
                            selectedSheet = sheet
                        }
                    } label: {
                        Text(sheet.title)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedSheet?.id == sheet.id
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear
                            )
                            .foregroundStyle(
                                selectedSheet?.id == sheet.id ? .primary : .secondary
                            )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("删除", role: .destructive) {
                            deleteSheet(sheet)
                        }
                    }

                    Divider().frame(height: 20)
                }

                Button(action: addSheet) {
                    Image(systemName: "plus")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 40)
        .background(.ultraThinMaterial)
    }

    private var spreadsheetGrid: some View {
        ScrollView([.horizontal, .vertical]) {
            if let sheet = selectedSheet {
                VStack(spacing: 1) {
                    // 列标题行
                    HStack(spacing: 1) {
                        Text("")
                            .padding(.horizontal, 4)
                            .frame(width: 50, height: 30)
                            .background(Color.secondary.opacity(0.1))

                        ForEach(0..<sheet.columnCount, id: \.self) { col in
                            Text(SpreadsheetCell.columnLetter(col))
                                .padding(.horizontal, 4)
                                .frame(width: 100, height: 30)
                                .background(
                                    isColumnSelected(col: col)
                                        ? Color.blue.opacity(0.15)
                                        : Color.secondary.opacity(0.1)
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    finishEditing()
                                    selectColumn(col)
                                }
                                .contextMenu {
                                    Button("删除该列", role: .destructive) {
                                        deleteColumn(at: col)
                                    }
                                }
                        }
                    }

                    // 数据行 - 使用 LazyVStack 实现垂直方向懒加载
                    LazyVStack(spacing: 1) {
                        ForEach(0..<sheet.rowCount, id: \.self) { row in
                            HStack(spacing: 1) {
                                Text("\(row + 1)")
                                    .padding(.horizontal, 4)
                                    .frame(width: 50, height: 30)
                                    .background(
                                        isRowSelected(row: row)
                                            ? Color.blue.opacity(0.15)
                                            : Color.secondary.opacity(0.1)
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        finishEditing()
                                        selectRow(row)
                                    }
                                    .contextMenu {
                                        Button("删除该行", role: .destructive) {
                                            deleteRow(at: row)
                                        }
                                    }

                                ForEach(0..<sheet.columnCount, id: \.self) { col in
                                    cellView(row: row, column: col)
                                }
                            }
                        }
                    }
                }
                .padding()
            } else {
                emptyState
            }
        }
    }

    @ViewBuilder
    private func cellView(row: Int, column: Int) -> some View {
        let cell = cellsByRowCol[row]?[column]
        let isSelected = isCellSelected(row: row, column: column)
        if let cell = cell, editingCell?.id == cell.id {
            // 编辑模式：只有一个 TextField
            TextField("", text: $editText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 4)
                .frame(width: 100, height: 30)
                .background(Color.accentColor.opacity(0.15))
                .onSubmit { finishEditing() }
                .focused($isCellFocused)
                .onAppear {
                    DispatchQueue.main.async {
                        isCellFocused = true
                    }
                }
        } else {
            // 显示模式：支持点击编辑与拖动选择
            Rectangle()
                .fill(
                    isSelected
                        ? Color.blue.opacity(0.15)
                        : Color.secondary.opacity(0.05)
                )
                .frame(width: 100, height: 30)
                .overlay(
                    Text(cell?.content ?? "")
                        .padding(.horizontal, 4)
                        .lineLimit(1),
                    alignment: .leading
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                selectionStart = (row, column)
                            }
                            let unitWidth: CGFloat = 101   // 100 + 1 spacing
                            let unitHeight: CGFloat = 31   // 30 + 1 spacing
                            let colOffset = Int(floor(value.location.x / unitWidth))
                            let rowOffset = Int(floor(value.location.y / unitHeight))
                            let maxCol = max(0, (selectedSheet?.columnCount ?? 1) - 1)
                            let maxRow = max(0, (selectedSheet?.rowCount ?? 1) - 1)
                            let newCol = max(0, min(column + colOffset, maxCol))
                            let newRow = max(0, min(row + rowOffset, maxRow))
                            selectionEnd = (newRow, newCol)
                        }
                        .onEnded { value in
                            isDragging = false
                            let distance = hypot(value.translation.width, value.translation.height)
                            if distance < 5 {
                                // 短距离移动视为点击：进入编辑
                                finishEditing()
                                selectionStart = (row, column)
                                selectionEnd = (row, column)
                                if let cell = cell {
                                    DispatchQueue.main.async {
                                        editingCell = cell
                                        editText = cell.content
                                    }
                                }
                            }
                        }
                )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tablecells")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("暂无表格")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("点击上方 + 按钮创建工作表")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }

    private var bottomToolbar: some View {
        HStack {
            Spacer()
            Button(action: addRow) {
                Label("添加行", systemImage: "plus")
            }
            .disabled(selectedSheet == nil)

            Button(action: addColumn) {
                Label("添加列", systemImage: "plus")
            }
            .disabled(selectedSheet == nil)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - 选中辅助

    /// 判断指定坐标是否在选中区域内。
    private func isCellSelected(row: Int, column: Int) -> Bool {
        guard let start = selectionStart, let end = selectionEnd else { return false }
        let minRow = min(start.row, end.row)
        let maxRow = max(start.row, end.row)
        let minCol = min(start.col, end.col)
        let maxCol = max(start.col, end.col)
        return row >= minRow && row <= maxRow && column >= minCol && column <= maxCol
    }

    /// 判断指定行是否被整行选中。
    private func isRowSelected(row: Int) -> Bool {
        guard let start = selectionStart, let end = selectionEnd else { return false }
        let minRow = min(start.row, end.row)
        let maxRow = max(start.row, end.row)
        let minCol = min(start.col, end.col)
        let maxCol = max(start.col, end.col)
        let colCount = selectedSheet?.columnCount ?? 0
        return row >= minRow && row <= maxRow && minCol == 0 && maxCol == colCount - 1
    }

    /// 判断指定列是否被整列选中。
    private func isColumnSelected(col: Int) -> Bool {
        guard let start = selectionStart, let end = selectionEnd else { return false }
        let minRow = min(start.row, end.row)
        let maxRow = max(start.row, end.row)
        let minCol = min(start.col, end.col)
        let maxCol = max(start.col, end.col)
        let rowCount = selectedSheet?.rowCount ?? 0
        return col >= minCol && col <= maxCol && minRow == 0 && maxRow == rowCount - 1
    }

    private func selectRow(_ row: Int) {
        guard let sheet = selectedSheet else { return }
        selectionStart = (row, 0)
        selectionEnd = (row, sheet.columnCount - 1)
    }

    private func selectColumn(_ column: Int) {
        guard let sheet = selectedSheet else { return }
        selectionStart = (0, column)
        selectionEnd = (sheet.rowCount - 1, column)
    }

    // MARK: - 复制粘贴

    #if os(macOS)
    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command) else { return event }
            guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return event }
            // 当正在编辑单元格时，让系统处理复制粘贴（TextField 自带）
            if self.editingCell != nil {
                return event
            }
            if chars == "c" {
                self.copySelection()
                return nil
            }
            if chars == "v" {
                self.paste()
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    #endif

    /// 将当前选中区域序列化为 TSV 并保存到应用内部剪贴板与系统剪贴板。
    private func copySelection() {
        guard selectionStart != nil, selectionEnd != nil else { return }
        let tsv = tsvFromSelection()
        clipboardTsv = tsv
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(tsv, forType: .string)
        #else
        UIPasteboard.general.string = tsv
        #endif
    }

    /// 使用应用内部剪贴板最近一次复制的内容进行粘贴，以选中区域起始位置展开。
    private func paste() {
        guard !clipboardTsv.isEmpty else { return }
        applyTsvToSelection(clipboardTsv)
    }

    /// 将选中区域转为 TSV 字符串。
    private func tsvFromSelection() -> String {
        guard let start = selectionStart, let end = selectionEnd else { return "" }
        let minRow = min(start.row, end.row)
        let maxRow = max(start.row, end.row)
        let minCol = min(start.col, end.col)
        let maxCol = max(start.col, end.col)

        var rows: [String] = []
        for r in minRow...maxRow {
            var cols: [String] = []
            for c in minCol...maxCol {
                let cell = cellsByRowCol[r]?[c]
                cols.append(cell?.content ?? "")
            }
            rows.append(cols.joined(separator: "\t"))
        }
        return rows.joined(separator: "\n")
    }

    /// 将 TSV 字符串解析并写入单元格，以选中区域起始位置为左上角展开粘贴，直接覆盖原有内容。
    private func applyTsvToSelection(_ tsv: String) {
        guard let sheet = selectedSheet else { return }
        // 过滤掉末尾因换行符产生的空行
        var rows = tsv.components(separatedBy: .newlines)
        if rows.last?.isEmpty == true {
            rows.removeLast()
        }
        let pasteStartRow = selectionStart?.row ?? 0
        let pasteStartCol = selectionStart?.col ?? 0

        for (rOffset, rowText) in rows.enumerated() {
            let cols = rowText.components(separatedBy: "\t")
            for (cOffset, content) in cols.enumerated() {
                let targetRow = pasteStartRow + rOffset
                let targetCol = pasteStartCol + cOffset
                guard targetRow < sheet.rowCount, targetCol < sheet.columnCount else { continue }

                if let cell = cellsByRowCol[targetRow]?[targetCol] {
                    cell.content = content
                } else {
                    let newCell = SpreadsheetCell(row: targetRow, column: targetCol, content: content)
                    newCell.sheet = sheet
                    modelContext.insert(newCell)
                }
            }
        }
        try? modelContext.save()
        loadCells()
    }

    // MARK: - 数据操作

    /// 根据当前选中的工作表，从数据库按需加载单元格数据，并重建索引字典。
    private func loadCells() {
        guard let sheet = selectedSheet else {
            cells = []
            cellsByRowCol = [:]
            return
        }
        let sheetID = sheet.id
        let descriptor = FetchDescriptor<SpreadsheetCell>(
            predicate: #Predicate { cell in
                cell.sheet?.id == sheetID
            },
            sortBy: [SortDescriptor(\.row), SortDescriptor(\.column)]
        )
        cells = (try? modelContext.fetch(descriptor)) ?? []
        rebuildCellIndex()
        // 如果当前正在编辑，同步 editText 避免与数据库内容脱节
        if let editing = editingCell,
           let updatedCell = cellsByRowCol[editing.row]?[editing.column],
           updatedCell.id == editing.id {
            editText = updatedCell.content
        }
    }

    /// 根据 cells 数组重建行-列索引字典，避免在 body 中重复计算。
    private func rebuildCellIndex() {
        var dict: [Int: [Int: SpreadsheetCell]] = [:]
        for cell in cells {
            dict[cell.row, default: [:]][cell.column] = cell
        }
        cellsByRowCol = dict
    }

    /// 结束当前编辑，如有变更则保存并同步双向链接。
    private func finishEditing() {
        guard let cell = editingCell else { return }
        let trimmed = editText
        if cell.content != trimmed {
            cell.content = trimmed
            cell.sheet?.updatedAt = Date()
            BlockRefEngine.syncRefs(
                sourceBlockID: cell.id,
                content: trimmed,
                context: modelContext
            )
            try? modelContext.save()
            loadCells()
        }
        editingCell = nil
    }

    private func addSheet() {
        finishEditing()
        let newSheet = SpreadsheetSheet(title: "表格 \(sheets.count + 1)")
        newSheet.project = project
        modelContext.insert(newSheet)
        newSheet.initializeCells(context: modelContext)
        try? modelContext.save()
        selectedSheet = newSheet
    }

    private func deleteSheet(_ sheet: SpreadsheetSheet) {
        finishEditing()
        BlockRefEngine.deleteRefs(for: sheet.id, context: modelContext)
        for cell in sheet.cells {
            BlockRefEngine.deleteRefs(for: cell.id, context: modelContext)
        }
        modelContext.delete(sheet)
        try? modelContext.save()
        if selectedSheet?.id == sheet.id {
            selectedSheet = sheets.first
        }
    }

    private func addRow() {
        finishEditing()
        guard let sheet = selectedSheet else { return }
        sheet.appendRow(context: modelContext)
        try? modelContext.save()
        loadCells()
    }

    private func addColumn() {
        finishEditing()
        guard let sheet = selectedSheet else { return }
        sheet.appendColumn(context: modelContext)
        try? modelContext.save()
        loadCells()
    }

    private func deleteRow(at row: Int) {
        finishEditing()
        guard let sheet = selectedSheet else { return }
        sheet.deleteRow(at: row, context: modelContext)
        try? modelContext.save()
        loadCells()
    }

    private func deleteColumn(at column: Int) {
        finishEditing()
        guard let sheet = selectedSheet else { return }
        sheet.deleteColumn(at: column, context: modelContext)
        try? modelContext.save()
        loadCells()
    }
}

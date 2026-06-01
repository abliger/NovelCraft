import SwiftUI
import SwiftData

/// 电子表格视图，以二维网格形式展示工作表中的单元格。
/// 采用"点击编辑"模式，同一时刻仅有一个单元格处于 TextField 编辑状态，避免大量输入框同时存在导致的性能问题。
struct SpreadsheetView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project

    @Query private var sheets: [SpreadsheetSheet]
    @State private var cells: [SpreadsheetCell] = []

    @State private var selectedSheet: SpreadsheetSheet?
    /// 当前正在编辑的单元格
    @State private var editingCell: SpreadsheetCell?
    /// 编辑中的临时文本
    @State private var editText: String = ""

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

    private var cellsByRowCol: [Int: [Int: SpreadsheetCell]] {
        var dict: [Int: [Int: SpreadsheetCell]] = [:]
        for cell in cells {
            dict[cell.row, default: [:]][cell.column] = cell
        }
        return dict
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
            if selectedSheet == nil, let first = sheets.first {
                selectedSheet = first
            }
            loadCells()
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
                Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                    // 列标题行
                    GridRow {
                        Text("")
                            .frame(width: 50, height: 30)
                            .background(Color.secondary.opacity(0.1))

                        ForEach(0..<sheet.columnCount, id: \.self) { col in
                            Text(SpreadsheetCell.columnLetter(col))
                                .frame(width: 100, height: 30)
                                .background(Color.secondary.opacity(0.1))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // 数据行
                    ForEach(0..<sheet.rowCount, id: \.self) { row in
                        GridRow {
                            Text("\(row + 1)")
                                .frame(width: 50, height: 30)
                                .background(Color.secondary.opacity(0.1))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(0..<sheet.columnCount, id: \.self) { col in
                                cellView(row: row, column: col)
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
        if let cell = cell, editingCell?.id == cell.id {
            // 编辑模式：只有一个 TextField
            TextField("", text: $editText)
                .textFieldStyle(.plain)
                .frame(width: 100, height: 30)
                .padding(.horizontal, 4)
                .background(Color.accentColor.opacity(0.15))
                .onSubmit { finishEditing() }
        } else {
            // 显示模式：纯文本，点击后进入编辑
            Text(cell?.content ?? "")
                .frame(width: 100, height: 30)
                .padding(.horizontal, 4)
                .background(Color.secondary.opacity(0.05))
                .lineLimit(1)
                .onTapGesture {
                    finishEditing()
                    if let cell = cell {
                        editingCell = cell
                        editText = cell.content
                    }
                }
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

    // MARK: - 操作

    /// 根据当前选中的工作表，从数据库按需加载单元格数据。
    private func loadCells() {
        guard let sheet = selectedSheet else {
            cells = []
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
}

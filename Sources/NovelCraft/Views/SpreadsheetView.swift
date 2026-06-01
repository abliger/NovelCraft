import SwiftUI
import SwiftData

/// 电子表格视图，以二维网格形式展示工作表中的单元格。
/// 支持多 Sheet 切换、单元格编辑、行列扩展，以及单元格内容中的双向链接。
struct SpreadsheetView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project

    @Query(sort: \SpreadsheetSheet.createdAt) private var allSheets: [SpreadsheetSheet]
    @Query(sort: \SpreadsheetCell.row) private var allCells: [SpreadsheetCell]

    @State private var selectedSheet: SpreadsheetSheet?

    private var sheets: [SpreadsheetSheet] {
        allSheets.filter { $0.project?.id == project.id }
    }

    private var cells: [SpreadsheetCell] {
        guard let sheetID = selectedSheet?.id else { return [] }
        return allCells.filter { $0.sheet?.id == sheetID }
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
        }
        .onChange(of: sheets) { _, newSheets in
            if selectedSheet == nil, let first = newSheets.first {
                selectedSheet = first
            }
        }
    }

    // MARK: - 子视图

    private var sheetTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(sheets) { sheet in
                    Button {
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

    private func cellView(row: Int, column: Int) -> some View {
        let cell = cellsByRowCol[row]?[column]
        return TextField("", text: Binding(
            get: { cell?.content ?? "" },
            set: { newValue in
                guard let cell = cell else { return }
                cell.content = newValue
                cell.sheet?.updatedAt = Date()
                BlockRefEngine.syncRefs(
                    sourceBlockID: cell.id,
                    content: newValue,
                    context: modelContext
                )
                try? modelContext.save()
            }
        ))
        .textFieldStyle(.plain)
        .frame(width: 100, height: 30)
        .padding(.horizontal, 4)
        .background(Color.secondary.opacity(0.05))
        .id("cell-\(row)-\(column)")
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

    private func addSheet() {
        let newSheet = SpreadsheetSheet(title: "表格 \(sheets.count + 1)")
        newSheet.project = project
        modelContext.insert(newSheet)
        newSheet.initializeCells(context: modelContext)
        try? modelContext.save()
        selectedSheet = newSheet
    }

    private func deleteSheet(_ sheet: SpreadsheetSheet) {
        BlockRefEngine.deleteRefs(for: sheet.id, context: modelContext)
        if let cells = sheet.cells {
            for cell in cells {
                BlockRefEngine.deleteRefs(for: cell.id, context: modelContext)
            }
        }
        modelContext.delete(sheet)
        try? modelContext.save()
        if selectedSheet?.id == sheet.id {
            selectedSheet = sheets.first
        }
    }

    private func addRow() {
        guard let sheet = selectedSheet else { return }
        sheet.appendRow(context: modelContext)
        try? modelContext.save()
    }

    private func addColumn() {
        guard let sheet = selectedSheet else { return }
        sheet.appendColumn(context: modelContext)
        try? modelContext.save()
    }
}

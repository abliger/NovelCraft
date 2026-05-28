import SwiftUI

/// 导出格式枚举，支持 Markdown、纯文本、PDF 与 EPUB 四种格式。
enum ExportFormat: String, CaseIterable {
    case markdown = "Markdown"
    case plainText = "纯文本"
    case pdf = "PDF"
    case epub = "EPUB"
    
    /// 每种格式对应的系统图标名称
    var icon: String {
        switch self {
        case .markdown: return "doc.text"
        case .plainText: return "doc.plaintext"
        case .pdf: return "doc.richtext"
        case .epub: return "book.closed"
        }
    }
    
    /// 文件扩展名
    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .plainText: return "txt"
        case .pdf: return "pdf"
        case .epub: return "epub"
        }
    }
}

/// 导出选项面板，允许用户选择导出范围、格式与是否包含元数据。
struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    let chapter: Chapter?
    
    @State private var selectedFormat: ExportFormat = .markdown
    @State private var exportScope: Int
    @State private var includeMetadata = true
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showSuccess = false
    @State private var exportError: String?
    
    init(project: Project, chapter: Chapter?) {
        self.project = project
        self.chapter = chapter
        self._exportScope = State(initialValue: chapter == nil ? 1 : 0)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("导出范围") {
                    Picker("范围", selection: $exportScope) {
                        if chapter != nil {
                            Text("当前章节").tag(0)
                        }
                        Text("整本小说").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("格式") {
                    Picker("格式", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Label(format.rawValue, systemImage: format.icon)
                                .tag(format)
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                Section("选项") {
                    Toggle("包含元数据", isOn: $includeMetadata)
                }
                
                if showSuccess, let url = exportURL {
                    Section("导出成功") {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("已保存至: \(url.lastPathComponent)")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("导出")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导出") {
                        export()
                    }
                    .disabled(isExporting)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 350)
        .alert("导出失败", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("确定") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }
    
    /// 调用 ExportEngine 执行导出，并处理结果状态。
    private func export() {
        isExporting = true
        exportError = nil
        
        Task {
            let engine = ExportEngine(project: project, chapter: chapter)
            let scope: ExportScope = exportScope == 0 ? .chapter : .fullProject
            
            do {
                let url = try engine.export(format: selectedFormat, scope: scope, includeMetadata: includeMetadata)
                await MainActor.run {
                    exportURL = url
                    showSuccess = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }
}

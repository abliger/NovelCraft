import SwiftUI

enum ExportFormat: String, CaseIterable {
    case markdown = "Markdown"
    case plainText = "纯文本"
    case pdf = "PDF"
    case epub = "EPUB"
    
    var icon: String {
        switch self {
        case .markdown: return "doc.text"
        case .plainText: return "doc.plaintext"
        case .pdf: return "doc.richtext"
        case .epub: return "book.closed"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .plainText: return "txt"
        case .pdf: return "pdf"
        case .epub: return "epub"
        }
    }
}

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    let chapter: Chapter?
    
    @State private var selectedFormat: ExportFormat = .markdown
    @State private var exportScope = 0
    @State private var includeMetadata = true
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showSuccess = false
    
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
    }
    
    private func export() {
        isExporting = true
        defer { isExporting = false }
        
        let engine = ExportEngine(project: project, chapter: chapter)
        let scope: ExportScope = exportScope == 0 ? .chapter : .fullProject
        
        do {
            let url = try engine.export(format: selectedFormat, scope: scope, includeMetadata: includeMetadata)
            exportURL = url
            showSuccess = true
        } catch {
            print("Export failed: \(error)")
        }
    }
}

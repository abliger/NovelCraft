import SwiftUI
import SwiftData

/// Markdown 编辑器视图，提供文本编辑、实时预览、查找替换与格式工具栏。
struct EditorView: View {
    @Environment(\.modelContext) private var modelContext
    
    let project: Project
    @Bindable var chapter: Chapter
    
    /// 编辑器中的文本内容（与 chapter.content 双向同步）
    @State private var editorText: String = ""
    /// 是否处于预览模式
    @State private var isPreviewMode = false
    /// 是否显示查找替换栏
    @State private var showFindBar = false
    /// 查找文本
    @State private var findText = ""
    /// 替换文本
    @State private var replaceText = ""
    /// 当前编辑器字体大小
    @State private var fontSize: CGFloat = 16
    /// 是否启用自动保存
    @State private var isAutoSaveEnabled = true
    /// 自动保存任务（用于 debounce）
    @State private var saveTask: Task<Void, Never>?
    /// 缓存的 Markdown 预览富文本
    @State private var cachedPreview: AttributedString = AttributedString("")
    
    /// 标识当前编辑器使用 Markdown 格式
    private var isMarkdown: Bool {
        true
    }
    
    var body: some View {
        VStack(spacing: 0) {
            editorToolbar
            
            Divider()
            
            ZStack {
                if isPreviewMode {
                    ScrollView {
                        Text(cachedPreview)
                            .padding()
                    }
                } else {
                    TextEditor(text: $editorText)
                        .font(.system(size: fontSize))
                        .lineSpacing(8)
                        .padding(.horizontal)
                        .scrollContentBackground(.hidden)
                        #if os(macOS)
                        .background(Color(.textBackgroundColor))
                        #else
                        .background(Color(.systemBackground))
                        #endif
                }
            }
            
            Divider()
            
            statusBar
        }
        .onAppear {
            editorText = chapter.content
            updatePreview()
        }
        .onChange(of: chapter.id) { _, _ in
            editorText = chapter.content
            updatePreview()
        }
        .onChange(of: editorText) { _, newValue in
            chapter.content = newValue
            updatePreview()
            if isAutoSaveEnabled {
                debouncedSave()
            }
        }
    }
    
    /// 延迟保存，避免每次按键都触发数据库写入
    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            try? modelContext.save()
        }
    }
    
    /// 异步更新 Markdown 预览缓存
    private func updatePreview() {
        cachedPreview = MarkdownParser.attributedString(from: editorText)
    }
    
    /// 编辑器顶部工具栏，提供 Markdown 格式插入与字体调整按钮。
    private var editorToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    applyMarkdown(prefix: "# ")
                } label: {
                    Image(systemName: "textformat.size")
                }
                .help("标题")
                
                Button {
                    applyMarkdown(prefix: "**", suffix: "**")
                } label: {
                    Image(systemName: "bold")
                }
                .help("粗体")
                
                Button {
                    applyMarkdown(prefix: "*", suffix: "*")
                } label: {
                    Image(systemName: "italic")
                }
                .help("斜体")
                
                Divider()
                    .frame(height: 20)
                
                Button {
                    applyMarkdown(prefix: "> ")
                } label: {
                    Image(systemName: "text.quote")
                }
                .help("引用")
                
                Button {
                    applyMarkdown(prefix: "- ")
                } label: {
                    Image(systemName: "list.bullet")
                }
                .help("列表")
                
                Button {
                    applyMarkdown(prefix: "```\n", suffix: "\n```")
                } label: {
                    Image(systemName: "curlybraces")
                }
                .help("代码块")
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    showFindBar.toggle()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .help("查找替换")
                
                Button {
                    isPreviewMode.toggle()
                } label: {
                    Image(systemName: isPreviewMode ? "pencil" : "eye")
                }
                .help(isPreviewMode ? "编辑" : "预览")
                
                Divider()
                    .frame(height: 20)
                
                Button {
                    fontSize = max(12, fontSize - 1)
                } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                .help("缩小字体")
                
                Text("\(Int(fontSize))")
                    .font(.caption)
                    .frame(width: 24)
                
                Button {
                    fontSize = min(32, fontSize + 1)
                } label: {
                    Image(systemName: "textformat.size.larger")
                }
                .help("放大字体")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
    
    /// 编辑器底部状态栏，展示字数、章节状态与查找替换控件。
    private var statusBar: some View {
        HStack(spacing: 16) {
            if showFindBar {
                HStack(spacing: 8) {
                    TextField("查找", text: $findText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                    TextField("替换", text: $replaceText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                    Button("替换") {
                        replace()
                    }
                    Button("全部替换") {
                        replaceAll()
                    }
                    Button {
                        showFindBar = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Label("\(chapter.wordCount) 字", systemImage: "textformat")
                    .font(.caption)
                
                Text(chapter.chapterStatus.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundStyle(statusColor)
                    .cornerRadius(4)
                
                if isAutoSaveEnabled {
                    Label("已保存", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
    
    /// 根据章节状态返回状态标签颜色
    private var statusColor: Color {
        switch chapter.chapterStatus {
        case .draft: return .gray
        case .revising: return .orange
        case .completed: return .green
        case .archived: return .blue
        }
    }
    
    /// 在当前文本前后插入 Markdown 标记符号
    private func applyMarkdown(prefix: String, suffix: String = "") {
        editorText = prefix + editorText + suffix
    }
    
    /// 查找并替换第一个匹配项
    private func replace() {
        if let range = editorText.range(of: findText) {
            editorText.replaceSubrange(range, with: replaceText)
        }
    }
    
    /// 查找并替换所有匹配项
    private func replaceAll() {
        editorText = editorText.replacingOccurrences(of: findText, with: replaceText)
    }
}

/// Markdown 解析工具，将 Markdown 文本转换为 AttributedString。
enum MarkdownParser {
    /// 将 Markdown 文本转换为 AttributedString，支持标题、粗体与斜体。
    static func attributedString(from text: String) -> AttributedString {
        var result = AttributedString(text)
        
        let headingPattern = try? NSRegularExpression(pattern: "^#{1,6}\\s+(.+)$", options: .anchorsMatchLines)
        if let pattern = headingPattern {
            let matches = pattern.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result) {
                    result[range].font = .title
                    result[range].foregroundColor = .primary
                }
            }
        }
        
        let boldPattern = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: [])
        if let pattern = boldPattern {
            let matches = pattern.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            for match in matches.reversed() {
                if let range = Range(match.range(at: 1), in: result) {
                    result[range].font = (result[range].font ?? .body).bold()
                }
            }
        }
        
        let italicPattern = try? NSRegularExpression(pattern: "\\*(.+?)\\*", options: [])
        if let pattern = italicPattern {
            let matches = pattern.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            for match in matches.reversed() {
                if let range = Range(match.range(at: 1), in: result) {
                    result[range].font = (result[range].font ?? .body).italic()
                }
            }
        }
        
        return result
    }
}

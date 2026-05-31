import SwiftUI
import SwiftData

/// Markdown 编辑器视图，提供文本编辑、实时预览、查找替换、双向链接与格式工具栏。
struct EditorView: View {
    @Environment(\ .modelContext) private var modelContext
    
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
    /// 是否显示内容块搜索面板
    @State private var showBlockSearch = false
    /// 是否显示反向链接面板
    @State private var showBacklinkPanel = false
    /// 当前章节的正向引用列表
    @State private var forwardRefs: [ContentBlockRef] = []
    
    /// 标识当前编辑器使用 Markdown 格式
    private var isMarkdown: Bool {
        true
    }
    
    var body: some View {
        VStack(spacing: 0) {
            editorToolbar
            
            Divider()
            
            HStack(spacing: 0) {
                // 主编辑/预览区域
                ZStack {
                    if isPreviewMode {
                        ScrollView {
                            Text(cachedPreview)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
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
                
                // 反向链接侧边栏
                if showBacklinkPanel {
                    Divider()
                    BacklinkPanelView(
                        blockID: chapter.id,
                        blockTitle: chapter.title
                    )
                    .frame(width: 260)
                }
            }
            
            Divider()
            
            statusBar
        }
        .onAppear {
            editorText = chapter.content
            updatePreview()
            loadForwardRefs()
        }
        .onChange(of: chapter.id) { _, _ in
            editorText = chapter.content
            updatePreview()
            loadForwardRefs()
        }
        .onChange(of: editorText) { _, newValue in
            chapter.content = newValue
            updatePreview()
            if isAutoSaveEnabled {
                debouncedSave()
            }
        }
        .task(id: chapter.id) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                FileSyncEngine.syncChapterToDisk(chapter, project: project)
            }
        }
        .sheet(isPresented: $showBlockSearch) {
            BlockRefSearchView(project: project) { targetID, title, isEmbed in
                insertBlockRef(targetID: targetID, title: title, isEmbed: isEmbed)
            }
        }
    }
    
    /// 延迟保存，避免每次按键都触发数据库写入
    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            syncRefsAndSave()
        }
    }
    
    /// 同步引用记录并保存数据库
    private func syncRefsAndSave() {
        BlockRefEngine.syncRefs(sourceBlockID: chapter.id, content: editorText, context: modelContext)
        try? modelContext.save()
        loadForwardRefs()
    }
    
    /// 加载当前章节的正向引用
    private func loadForwardRefs() {
        forwardRefs = BlockRefEngine.forwardRefs(from: chapter.id, context: modelContext)
    }
    
    /// 在文本末尾插入块引用或嵌入语法
    private func insertBlockRef(targetID: UUID, title: String, isEmbed: Bool) {
        let syntax: String
        if isEmbed {
            syntax = "\n{{\(targetID.uuidString)}}\n"
        } else {
            let safeTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
            syntax = "\n((\(targetID.uuidString) \"\(safeTitle)\"))\n"
        }
        editorText += syntax
    }
    
    /// 异步更新 Markdown 预览缓存
    @MainActor
    private func updatePreview() {
        Task {
            cachedPreview = await MarkdownParser.attributedStringAsync(from: editorText)
        }
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
                
                Divider()
                    .frame(height: 20)
                
                // 双向链接按钮
                Button {
                    showBlockSearch = true
                } label: {
                    Image(systemName: "link.badge.plus")
                }
                .help("插入双向链接")
                
                // 反向链接面板开关
                Button {
                    withAnimation {
                        showBacklinkPanel.toggle()
                    }
                } label: {
                    Image(systemName: showBacklinkPanel ? "link.circle.fill" : "link.circle")
                }
                .help("反向链接面板")
                
                if !forwardRefs.isEmpty {
                    Text("\(forwardRefs.count)")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.purple.opacity(0.15))
                        .cornerRadius(4)
                }
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

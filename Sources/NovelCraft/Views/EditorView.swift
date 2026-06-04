import SwiftUI
import SwiftData

/// Markdown 编辑器视图，提供文本编辑、实时预览、查找替换、双向链接与格式工具栏。
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
    @AppStorage("editorFontSize") private var editorFontSize: Double = 16
    /// 编辑器行间距
    @AppStorage("editorLineSpacing") private var editorLineSpacing: Double = 8
    /// 是否启用自动保存（autoSaveInterval > 0 视为启用）
    @AppStorage("autoSaveInterval") private var autoSaveInterval: Double = 30
    /// 自动保存任务（用于 debounce）
    @State private var saveTask: Task<Void, Never>?
    /// 预览更新任务（用于取消旧任务）
    @State private var previewTask: Task<Void, Never>?
    /// 缓存的 Markdown 预览 HTML
    @State private var cachedPreviewHTML: String = ""
    /// 是否显示内容块搜索面板
    @State private var showBlockSearch = false
    /// 是否显示反向链接面板
    @State private var showBacklinkPanel = false
    /// 当前章节的正向引用列表
    @State private var forwardRefs: [ContentBlockRef] = []
    /// 缓存的插件工具栏项，避免每次 body 评估重新计算
    @State private var toolbarItems: [PluginToolbarItem] = []
    /// 是否显示图片插入面板
    @State private var showImageInsert = false
    /// 是否显示 AI 生成面板
    @State private var showAIGeneration = false
    /// 是否显示细纲编辑面板
    @State private var showSynopsisPanel = false
    /// 图片处理方式（从设置读取）
    @AppStorage("imageHandlingMode") private var imageHandlingMode = 1
    /// 是否允许下载网络图片
    @AppStorage("allowDownloadWebImages") private var allowDownloadWebImages = true
    
    /// 标识当前编辑器使用 Markdown 格式
    private var isMarkdown: Bool {
        true
    }
    
    /// 是否启用自动保存
    private var isAutoSaveEnabled: Bool {
        autoSaveInterval > 0
    }
    
    /// 当前字体大小
    private var fontSize: CGFloat {
        CGFloat(editorFontSize)
    }
    
    /// 当前行间距
    private var lineSpacing: CGFloat {
        CGFloat(editorLineSpacing)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            editorToolbar
            
            Divider()
            
            HStack(spacing: 0) {
                // 主编辑/预览区域
                ZStack {
                    if isPreviewMode {
                        PreviewWebView(
                            htmlString: cachedPreviewHTML,
                            baseURL: URL(fileURLWithPath: project.storagePath)
                        )
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        TextEditor(text: $editorText)
                            .font(.system(size: fontSize))
                            .lineSpacing(lineSpacing)
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
                
                // AI 生成侧边栏
                if showAIGeneration {
                    Divider()
                    AIGenerationPanelView(chapter: chapter)
                        .frame(minWidth: 300, idealWidth: 320, maxWidth: 380)
                }
                
                // 细纲编辑侧边栏
                if showSynopsisPanel {
                    Divider()
                    SynopsisPanelView(chapter: chapter, project: project)
                        .frame(minWidth: 280, idealWidth: 300, maxWidth: 360)
                }
            }
            
            Divider()
            
            statusBar
        }
        .onAppear {
            editorText = chapter.content
            loadSynopsisFromDisk()
            updatePreview()
            loadForwardRefs()
            toolbarItems = PluginManager.shared.allToolbarItems
        }
        .onDisappear {
            saveTask?.cancel()
            previewTask?.cancel()
        }
        .onChange(of: chapter.id) { _, _ in
            editorText = chapter.content
            loadSynopsisFromDisk()
            updatePreview()
            loadForwardRefs()
        }
        .onChange(of: chapter.content) { _, newValue in
            if newValue != editorText {
                editorText = newValue
                updatePreview()
            }
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
                let ch = chapter
                let pr = project
                FileSyncEngine.syncChapterToDisk(ch, project: pr)
                FileSyncEngine.syncSynopsisToDisk(ch, project: pr)
            }
        }
        .sheet(isPresented: $showBlockSearch) {
            BlockRefSearchView(project: project) { targetID, title, isEmbed in
                insertBlockRef(targetID: targetID, title: title, isEmbed: isEmbed)
            }
        }
        .sheet(isPresented: $showImageInsert) {
            ImageInsertView(project: project) { markdown in
                insertImageMarkdown(markdown)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .aiGenerationPanelToggle)) { _ in
            withAnimation {
                showAIGeneration.toggle()
            }
        }
        #if os(macOS)
        .dropDestination(for: URL.self) { urls, location in
            Task { await handleDroppedURLs(urls) }
            return true
        } isTargeted: { _ in
            // 拖放悬停状态可在此添加视觉反馈
        }
        #endif
    }
    
    /// 延迟保存，避免每次按键都触发数据库写入
    private func debouncedSave() {
        saveTask?.cancel()
        let capturedChapterID = chapter.id
        let capturedText = editorText
        let ctx = modelContext
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard chapter.id == capturedChapterID else { return }
                let processedText = PluginManager.shared.processContent(capturedText, chapter: chapter)
                if processedText != capturedText {
                    editorText = processedText
                    chapter.content = processedText
                }
                BlockRefEngine.syncRefs(sourceBlockID: capturedChapterID, content: processedText, context: ctx)
                try? ctx.save()
                loadForwardRefs()
            }
        }
    }
    
    /// 同步引用记录并保存数据库
    private func syncRefsAndSave(chapterID: UUID, text: String) {
        BlockRefEngine.syncRefs(sourceBlockID: chapterID, content: text, context: modelContext)
        try? modelContext.save()
        loadForwardRefs()
    }
    
    /// 加载当前章节的正向引用
    private func loadForwardRefs() {
        forwardRefs = BlockRefEngine.forwardRefs(from: chapter.id, context: modelContext)
    }
    
    /// 从文件系统加载当前章节的细纲，若存在则覆盖内存中的值（不触发数据库保存）
    private func loadSynopsisFromDisk() {
        if let synopsis = FileSyncEngine.loadSynopsisFromDisk(chapter, project: project) {
            chapter.synopsis = synopsis
        }
    }
    
    /// 在文本末尾插入块引用或嵌入语法
    private func insertBlockRef(targetID: UUID, title: String, isEmbed: Bool) {
        let syntax: String
        if isEmbed {
            syntax = "\n{{\(targetID.uuidString)}}\n"
        } else {
            // 转义锚文本中的特殊字符：")" 和 "\"
            var safeTitle = title.replacingOccurrences(of: "\\", with: "\\\\")
            safeTitle = safeTitle.replacingOccurrences(of: "\"", with: "\\\"")
            safeTitle = safeTitle.replacingOccurrences(of: ")", with: "\\)")
            syntax = "\n((\(targetID.uuidString) \"\(safeTitle)\"))\n"
        }
        editorText += syntax
    }
    
    /// 在文本末尾插入 Markdown 图片语法
    private func insertImageMarkdown(_ markdown: String) {
        editorText += "\n\(markdown)\n"
    }
    
    /// 处理拖放的图片 URL
    @MainActor
    private func handleDroppedURLs(_ urls: [URL]) async {
        guard !isPreviewMode else { return }
        
        let mode = ImageAssetEngine.HandlingMode(rawValue: imageHandlingMode) ?? .copyLocal
        
        for url in urls {
            guard ImageAssetEngine.isImageFile(url) else { continue }
            
            let effectiveMode: ImageAssetEngine.HandlingMode
            if mode == .downloadWeb && !allowDownloadWebImages && url.scheme?.hasPrefix("http") == true {
                effectiveMode = .reference
            } else {
                effectiveMode = mode
            }
            
            let path = await ImageAssetEngine.processImage(url: url, project: project, mode: effectiveMode)
            let alt = url.deletingPathExtension().lastPathComponent
            let markdown = "![\(alt)](\(path))"
            editorText += "\n\(markdown)\n"
        }
    }
    
    /// 异步更新 Markdown 预览缓存，取消旧任务避免竞态
    @MainActor
    private func updatePreview() {
        previewTask?.cancel()
        let text = editorText
        let path = project.storagePath
        previewTask = Task {
            let preview = await MarkdownParser.htmlAsync(from: text, baseURL: URL(fileURLWithPath: path))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                cachedPreviewHTML = preview
            }
        }
    }
    
    /// 插件贡献的工具栏按钮（前置位置）。
    @ViewBuilder
    private var pluginToolbarLeadingItems: some View {
        let items = toolbarItems.filter { $0.position == .leading }
        if !items.isEmpty {
            ForEach(items, id: \.id) { item in
                Button {
                    item.action()
                } label: {
                    Image(systemName: item.icon)
                }
                .help(item.tooltip)
            }
            Divider()
                .frame(height: 20)
        }
    }
    
    /// 插件贡献的工具栏按钮（后置位置）。
    @ViewBuilder
    private var pluginToolbarTrailingItems: some View {
        let items = toolbarItems.filter { $0.position == .trailing }
        if !items.isEmpty {
            ForEach(items, id: \.id) { item in
                Button {
                    item.action()
                } label: {
                    Image(systemName: item.icon)
                }
                .help(item.tooltip)
            }
            Divider()
                .frame(height: 20)
        }
    }
    
    /// 编辑器顶部工具栏，提供 Markdown 格式插入与字体调整按钮。
    private var editorToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                pluginToolbarLeadingItems
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
                
                // 插入图片按钮
                Button {
                    showImageInsert = true
                } label: {
                    Image(systemName: "photo")
                }
                .help("插入图片")
                
                // 反向链接面板开关
                Button {
                    withAnimation {
                        showBacklinkPanel.toggle()
                    }
                } label: {
                    Image(systemName: showBacklinkPanel ? "link.circle.fill" : "link.circle")
                }
                .help("反向链接面板")
                
                // 细纲编辑面板开关
                Button {
                    withAnimation {
                        showSynopsisPanel.toggle()
                    }
                } label: {
                    Image(systemName: showSynopsisPanel ? "doc.text.fill" : "doc.text")
                        .foregroundStyle(showSynopsisPanel ? Color.accentColor : .primary)
                }
                .help("编辑细纲")
                
                pluginToolbarTrailingItems
                
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
                    editorFontSize = max(12, editorFontSize - 1)
                } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                .help("缩小字体")
                
                Text("\(Int(editorFontSize))")
                    .font(.caption)
                    .frame(width: 24)
                
                Button {
                    editorFontSize = min(32, editorFontSize + 1)
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
    
    /// 在当前文本末尾插入 Markdown 标记符号。
    ///
    /// 注意：由于 SwiftUI `TextEditor` 不提供光标位置 API，标记会插入到文本末尾。
    /// 用户可手动复制标记到目标位置。如需光标感知插入，需将编辑器替换为
    /// 平台特定的 `NSTextView`/`UITextView` 封装。
    private func applyMarkdown(prefix: String, suffix: String = "") {
        let insertion: String
        if suffix.isEmpty {
            // 行首标记（标题、引用、列表）
            insertion = prefix
        } else {
            // 包裹标记（粗体、斜体、代码块）
            insertion = prefix + suffix
        }
        if editorText.isEmpty {
            editorText = insertion
        } else if editorText.hasSuffix("\n") {
            editorText += insertion
        } else {
            editorText += "\n" + insertion
        }
    }
    
    /// 查找并替换第一个匹配项
    private func replace() {
        guard !findText.isEmpty else { return }
        if let range = editorText.range(of: findText) {
            editorText.replaceSubrange(range, with: replaceText)
        }
    }
    
    /// 查找并替换所有匹配项
    private func replaceAll() {
        guard !findText.isEmpty else { return }
        editorText = editorText.replacingOccurrences(of: findText, with: replaceText)
    }
}

// MARK: - 细纲编辑面板

/// 章节细纲编辑侧边栏，允许用户为当前章节编写或修改细纲。
/// 细纲会同步写入文件系统（`章名_UUID前缀.synopsis.md`），并在加载时优先从文件读取。
struct SynopsisPanelView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var chapter: Chapter
    let project: Project
    
    @State private var synopsisText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 面板标题
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(Color.accentColor)
                Text("章节细纲")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)
            
            Divider()
            
            // 编辑区
            VStack(alignment: .leading, spacing: 8) {
                Text("为「\(chapter.title)」编写细纲")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 12)
                
                TextEditor(text: $synopsisText)
                    .font(.system(size: 14))
                    .lineSpacing(6)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .focused($isFocused)
                    .onChange(of: synopsisText) { _, newValue in
                        chapter.synopsis = newValue
                        chapter.updatedAt = Date()
                        try? modelContext.save()
                        FileSyncEngine.syncSynopsisToDisk(chapter, project: project)
                    }
                
                if chapter.synopsis.isEmpty {
                    Text("编写细纲有助于 AI 生成更贴合情节的内容。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
        }
        #if os(macOS)
        .frame(minWidth: 280, minHeight: 400)
        #endif
        .onAppear {
            synopsisText = chapter.synopsis
        }
        .onChange(of: chapter.id) { _, _ in
            synopsisText = chapter.synopsis
        }
    }
}

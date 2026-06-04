import SwiftUI
import SwiftData

/// 笔记项目卷 Markdown 编辑器，提供与章节编辑器一致的编辑、预览、查找替换与格式工具栏。
struct VolumeNoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    
    let project: Project
    @Bindable var volume: Volume
    
    /// 编辑器中的文本内容（与 volume.outline 双向同步）
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
    /// 是否显示图片插入面板
    @State private var showImageInsert = false
    /// 图片处理方式（从设置读取）
    @AppStorage("imageHandlingMode") private var imageHandlingMode = 1
    /// 是否允许下载网络图片
    @AppStorage("allowDownloadWebImages") private var allowDownloadWebImages = true
    
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
            
            Divider()
            
            statusBar
        }
        .onAppear {
            editorText = volume.outline
            loadOutlineFromDisk()
            updatePreview()
        }
        .onDisappear {
            saveTask?.cancel()
            previewTask?.cancel()
        }
        .onChange(of: volume.id) { _, _ in
            editorText = volume.outline
            loadOutlineFromDisk()
            updatePreview()
        }
        .onChange(of: volume.outline) { _, newValue in
            if newValue != editorText {
                editorText = newValue
                updatePreview()
            }
        }
        .onChange(of: editorText) { _, newValue in
            volume.outline = newValue
            updatePreview()
            if isAutoSaveEnabled {
                debouncedSave()
            }
        }
        .task(id: volume.id) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                let vol = volume
                let pr = project
                FileSyncEngine.syncVolumeToDisk(vol, project: pr)
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
        #if os(macOS)
        .dropDestination(for: URL.self) { urls, location in
            Task { await handleDroppedURLs(urls) }
            return true
        } isTargeted: { _ in
            // 拖放悬停状态可在此添加视觉反馈
        }
        #endif
    }
    
    /// 从文件系统加载卷内容，若存在则覆盖内存中的值
    private func loadOutlineFromDisk() {
        if let outline = FileSyncEngine.loadVolumeFromDisk(volume, project: project) {
            volume.outline = outline
            try? modelContext.save()
        }
    }
    
    /// 延迟保存，避免每次按键都触发数据库写入
    private func debouncedSave() {
        saveTask?.cancel()
        let capturedVolumeID = volume.id
        let capturedText = editorText
        let ctx = modelContext
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard volume.id == capturedVolumeID else { return }
                volume.outline = capturedText
                try? ctx.save()
                FileSyncEngine.syncVolumeToDisk(volume, project: project)
            }
        }
    }
    
    /// 同步到数据库与文件系统
    private func syncAndSave() {
        try? modelContext.save()
        FileSyncEngine.syncVolumeToDisk(volume, project: project)
    }
    
    /// 在文本末尾插入块引用或嵌入语法
    private func insertBlockRef(targetID: UUID, title: String, isEmbed: Bool) {
        let syntax: String
        if isEmbed {
            syntax = "\n{{\(targetID.uuidString)}}\n"
        } else {
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
                
                // 插入图片按钮
                Button {
                    showImageInsert = true
                } label: {
                    Image(systemName: "photo")
                }
                .help("插入图片")
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
    
    /// 编辑器底部状态栏，展示字数与查找替换控件。
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
                Label("\(editorText.count) 字", systemImage: "textformat")
                    .font(.caption)
                
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
    
    /// 在当前文本末尾插入 Markdown 标记符号。
    private func applyMarkdown(prefix: String, suffix: String = "") {
        let insertion: String
        if suffix.isEmpty {
            insertion = prefix
        } else {
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

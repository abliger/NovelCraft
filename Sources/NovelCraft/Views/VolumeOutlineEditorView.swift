import SwiftUI
import SwiftData

/// 小说项目分卷大纲编辑器，提供简洁的文本编辑与文件同步。
struct VolumeOutlineEditorView: View {
    @Environment(\.modelContext) private var modelContext
    
    let project: Project
    @Bindable var volume: Volume
    
    /// 编辑器中的文本内容（与 volume.outline 双向同步）
    @State private var editorText: String = ""
    /// 当前编辑器字体大小
    @AppStorage("editorFontSize") private var editorFontSize: Double = 16
    /// 编辑器行间距
    @AppStorage("editorLineSpacing") private var editorLineSpacing: Double = 8
    /// 自动保存任务（用于 debounce）
    @State private var saveTask: Task<Void, Never>?
    
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
            // 顶部标题栏
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                Text("分卷大纲 · \(volume.title)")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // 编辑区
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
            
            Divider()
            
            // 底部状态栏
            HStack {
                Spacer()
                Text("\(editorText.count) 字")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
        }
        .onAppear {
            editorText = volume.outline
            loadOutlineFromDisk()
            loadFromOutlineNode()
        }
        .onDisappear {
            saveTask?.cancel()
            syncAndSave()
        }
        .onChange(of: volume.id) { _, _ in
            editorText = volume.outline
            loadOutlineFromDisk()
            loadFromOutlineNode()
        }
        .onChange(of: volume.outline) { _, newValue in
            if newValue != editorText {
                editorText = newValue
            }
        }
        .onChange(of: editorText) { _, newValue in
            volume.outline = newValue
            debouncedSave()
        }
        .task(id: volume.id) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                FileSyncEngine.syncVolumeToDisk(volume, project: project)
            }
        }
    }
    
    /// 从文件系统加载卷大纲，若存在则覆盖内存中的值
    private func loadOutlineFromDisk() {
        if let outline = FileSyncEngine.loadVolumeFromDisk(volume, project: project) {
            volume.outline = outline
            try? modelContext.save()
        }
    }
    
    /// 查找细纲中 title 与当前卷名相同的卷大纲节点（parent == nil）
    private func findMatchingVolumeOutlineNode() -> OutlineNode? {
        project.outlineNodes.first { $0.parent == nil && $0.title == volume.title }
    }
    
    /// 从细纲卷大纲节点加载内容，若找到则覆盖到编辑器与 volume.outline
    private func loadFromOutlineNode() {
        guard let node = findMatchingVolumeOutlineNode() else { return }
        if !node.content.isEmpty, node.content != volume.outline {
            volume.outline = node.content
            editorText = node.content
            try? modelContext.save()
        }
    }
    
    /// 延迟保存，避免每次按键都触发数据库写入
    private func debouncedSave() {
        saveTask?.cancel()
        let capturedVolumeID = volume.id
        let capturedText = editorText
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            // 防竞态：若卷已切换则跳过本次保存
            guard volume.id == capturedVolumeID else { return }
            await MainActor.run {
                volume.outline = capturedText
                syncAndSave()
            }
        }
    }
    
    /// 同步到数据库、文件系统与细纲卷大纲节点
    private func syncAndSave() {
        try? modelContext.save()
        FileSyncEngine.syncVolumeToDisk(volume, project: project)
        
        if let node = findMatchingVolumeOutlineNode() {
            node.content = volume.outline
            node.title = volume.title
            node.updatedAt = Date()
            try? modelContext.save()
        } else if !volume.outline.isEmpty {
            let order = project.outlineNodes.filter { $0.parent == nil }.count
            let newNode = OutlineNode(title: volume.title, content: volume.outline, order: order, nodeType: "volume")
            newNode.project = project
            modelContext.insert(newNode)
            try? modelContext.save()
        }
    }
}

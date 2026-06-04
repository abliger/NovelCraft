import SwiftUI
import SwiftData

/// 章节树形侧边栏视图，展示项目的卷/章节层级结构，支持增删改与排序。
struct ChapterTreeView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project?
    @Binding var selectedChapter: Chapter?
    @Binding var selectedVolume: Volume?
    @Binding var expandedVolumes: Set<UUID>
    
    @FocusState private var renameFocus: Bool
    
    init(project: Project?, selectedChapter: Binding<Chapter?>, selectedVolume: Binding<Volume?>, expandedVolumes: Binding<Set<UUID>>) {
        self.project = project
        self._selectedChapter = selectedChapter
        self._selectedVolume = selectedVolume
        self._expandedVolumes = expandedVolumes
    }
    
    /// 按 order 排序后的卷列表
    private var sortedVolumes: [Volume] {
        (project?.volumes ?? []).sorted { $0.order < $1.order }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    addVolume()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .help("新建卷")
                Button {
                    addChapter()
                } label: {
                    Image(systemName: "doc.badge.plus")
                }
                .help("新建章节")
                .disabled(sortedVolumes.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            List {
                ForEach(sortedVolumes) { volume in
                    VolumeSection(
                        volume: volume,
                        selectedChapter: $selectedChapter,
                        selectedVolume: $selectedVolume,
                        isExpanded: expandedVolumes.contains(volume.id),
                        onToggle: { toggleVolume(volume.id) }
                    )
                }
            }
            .listStyle(.sidebar)
        }
    }
    
    /// 切换指定卷的展开/收起状态
    private func toggleVolume(_ id: UUID) {
        withAnimation {
            if expandedVolumes.contains(id) {
                expandedVolumes.remove(id)
            } else {
                expandedVolumes.insert(id)
            }
        }
    }
    
    /// 在当前项目中新建一个卷，并自动展开
    private func addVolume() {
        guard let project = project else { return }
        let order = sortedVolumes.count
        let volume = Volume(title: "第\(order + 1)卷", order: order)
        volume.project = project
        modelContext.insert(volume)
        try? modelContext.save()
        expandedVolumes.insert(volume.id)
    }
    
    /// 在当前上下文中新建一个章节。
    /// 优先顺序：当前选中章节所属的卷 → 当前选中的卷 → 唯一展开的卷 → 最后一卷。
    private func addChapter() {
        let targetVolume: Volume?
        if let chapter = selectedChapter {
            targetVolume = chapter.volume
        } else if let volume = selectedVolume {
            targetVolume = volume
        } else if expandedVolumes.count == 1,
                  let volumeID = expandedVolumes.first {
            targetVolume = sortedVolumes.first { $0.id == volumeID }
        } else {
            targetVolume = sortedVolumes.last
        }
        
        guard let volume = targetVolume else { return }
        let order = volume.chapters.count
        let chapter = Chapter(title: "第\(order + 1)章", order: order)
        chapter.volume = volume
        modelContext.insert(chapter)
        try? modelContext.save()
        selectedChapter = chapter
        selectedVolume = nil
        expandedVolumes.insert(volume.id)
    }
}

/// 卷分区视图，展示卷标题及下属章节列表，支持展开/收起、重命名与删除。
struct VolumeSection: View {
    @Environment(\.modelContext) private var modelContext
    let volume: Volume
    @Binding var selectedChapter: Chapter?
    @Binding var selectedVolume: Volume?
    let isExpanded: Bool
    let onToggle: () -> Void
    
    @State private var isRenaming = false
    @State private var renameText = ""
    @FocusState private var renameFocus: Bool
    
    /// 按 order 排序后的章节列表
    private var sortedChapters: [Chapter] {
        volume.chapters.sorted { $0.order < $1.order }
    }
    
    /// 当前卷是否被选中
    private var isSelected: Bool {
        selectedVolume?.id == volume.id
    }
    
    var body: some View {
        Section {
            if isExpanded {
                ForEach(sortedChapters) { chapter in
                    ChapterRow(
                        chapter: chapter,
                        selectedChapter: $selectedChapter,
                        selectedVolume: $selectedVolume
                    )
                }
                .onDelete { indexSet in
                    deleteChapters(at: indexSet)
                }
                .onMove { indices, newOffset in
                    moveChapters(from: indices, to: newOffset)
                }
            }
        } header: {
            HStack {
                Button(action: onToggle) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "收起" : "展开")
                
                if isRenaming {
                    TextField("卷名", text: $renameText, onCommit: {
                        volume.title = renameText.isEmpty ? volume.title : renameText
                        volume.updatedAt = Date()
                        try? modelContext.save()
                        isRenaming = false
                    })
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 150)
                    .focused($renameFocus)
                    .onAppear {
                        renameFocus = true
                    }
                } else {
                    Text(volume.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text("\(sortedChapters.count) 章")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Menu {
                    Button("重命名") {
                        renameText = volume.title
                        isRenaming = true
                    }
                    Button("添加章节") {
                        addChapter()
                    }
                    Divider()
                    Button("删除", role: .destructive) {
                        for chapter in sortedChapters {
                            if selectedChapter?.id == chapter.id {
                                selectedChapter = nil
                            }
                            BlockRefEngine.deleteRefs(for: chapter.id, context: modelContext)
                        }
                        if selectedVolume?.id == volume.id {
                            selectedVolume = nil
                        }
                        BlockRefEngine.deleteRefs(for: volume.id, context: modelContext)
                        modelContext.delete(volume)
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
                .help("卷操作")
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(isSelected ? Color.accentColor : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                onToggle()
            }
            .onTapGesture {
                selectedVolume = volume
                selectedChapter = nil
            }
        }
    }
    
    /// 在当前卷中新建章节
    private func addChapter() {
        let order = sortedChapters.count
        let chapter = Chapter(title: "第\(order + 1)章", order: order)
        chapter.volume = volume
        modelContext.insert(chapter)
        try? modelContext.save()
        selectedChapter = chapter
        selectedVolume = nil
    }
    
    /// 删除指定索引位置的章节
    private func deleteChapters(at indexSet: IndexSet) {
        for index in indexSet {
            let chapter = sortedChapters[index]
            if selectedChapter?.id == chapter.id {
                selectedChapter = nil
            }
            BlockRefEngine.deleteRefs(for: chapter.id, context: modelContext)
            modelContext.delete(chapter)
        }
        try? modelContext.save()
    }
    
    /// 移动章节顺序并更新 order 字段
    private func moveChapters(from source: IndexSet, to destination: Int) {
        var chapters = sortedChapters
        chapters.move(fromOffsets: source, toOffset: destination)
        for (index, chapter) in chapters.enumerated() {
            chapter.order = index
        }
        try? modelContext.save()
    }
}

/// 单行章节视图，展示章节标题、字数与状态标识，支持重命名、状态切换与删除。
struct ChapterRow: View {
    @Environment(\.modelContext) private var modelContext
    let chapter: Chapter
    @Binding var selectedChapter: Chapter?
    @Binding var selectedVolume: Volume?
    
    @State private var isRenaming = false
    @State private var renameText = ""
    @FocusState private var renameFocus: Bool
    
    /// 当前章节是否被选中
    private var isSelected: Bool {
        selectedChapter?.id == chapter.id
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(chapter.chapterStatus.color)
                .frame(width: 8, height: 8)
            
            if isRenaming {
                TextField("章节名", text: $renameText, onCommit: {
                    chapter.title = renameText.isEmpty ? chapter.title : renameText
                    chapter.updatedAt = Date()
                    try? modelContext.save()
                    isRenaming = false
                })
                .textFieldStyle(.plain)
                .focused($renameFocus)
                .onAppear {
                    renameFocus = true
                }
            } else {
                Text(chapter.title)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text("\(chapter.wordCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Menu {
                ForEach(ChapterStatus.allCases, id: \.self) { status in
                    Button(status.displayName) {
                        chapter.chapterStatus = status
                        chapter.updatedAt = Date()
                        try? modelContext.save()
                    }
                }
                Divider()
                Button("重命名") {
                    renameText = chapter.title
                    isRenaming = true
                }
                Button("删除", role: .destructive) {
                    if selectedChapter?.id == chapter.id {
                        selectedChapter = nil
                    }
                    BlockRefEngine.deleteRefs(for: chapter.id, context: modelContext)
                    modelContext.delete(chapter)
                    try? modelContext.save()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 16)
            .opacity(selectedChapter?.id == chapter.id ? 1 : 0)
            .help("章节操作")
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedChapter = chapter
            selectedVolume = nil
        }
        .contextMenu {
            Button("重命名") {
                renameText = chapter.title
                isRenaming = true
            }
            
            let pluginActions = PluginManager.shared.allChapterActions
            if !pluginActions.isEmpty {
                Divider()
                ForEach(pluginActions, id: \.id) { action in
                    Button {
                        action.action(chapter)
                    } label: {
                        Label(action.title, systemImage: action.icon)
                    }
                }
            }
            
            Divider()
            Button("删除", role: .destructive) {
                if selectedChapter?.id == chapter.id {
                    selectedChapter = nil
                }
                BlockRefEngine.deleteRefs(for: chapter.id, context: modelContext)
                modelContext.delete(chapter)
                try? modelContext.save()
            }
        }
    }
    

}

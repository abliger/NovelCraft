import SwiftUI
import SwiftData

struct ChapterTreeView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project?
    @Binding var selectedChapter: Chapter?
    
    @State private var isAddingVolume = false
    @State private var newVolumeTitle = ""
    @State private var expandedVolumes: Set<UUID> = []
    
    private var sortedVolumes: [Volume] {
        (project?.volumes ?? []).sorted { $0.order < $1.order }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("章节")
                    .font(.headline)
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
            
            List(selection: $selectedChapter) {
                ForEach(sortedVolumes) { volume in
                    VolumeSection(
                        volume: volume,
                        selectedChapter: $selectedChapter,
                        isExpanded: expandedVolumes.contains(volume.id),
                        onToggle: { toggleVolume(volume.id) }
                    )
                }
            }
            .listStyle(.sidebar)
        }
    }
    
    private func toggleVolume(_ id: UUID) {
        if expandedVolumes.contains(id) {
            expandedVolumes.remove(id)
        } else {
            expandedVolumes.insert(id)
        }
    }
    
    private func addVolume() {
        guard let project = project else { return }
        let order = sortedVolumes.count
        let volume = Volume(title: "第\(order + 1)卷", order: order)
        volume.project = project
        modelContext.insert(volume)
        try? modelContext.save()
        expandedVolumes.insert(volume.id)
    }
    
    private func addChapter() {
        guard let volume = sortedVolumes.last else { return }
        let order = (volume.chapters ?? []).count
        let chapter = Chapter(title: "第\(order + 1)章", order: order)
        chapter.volume = volume
        modelContext.insert(chapter)
        try? modelContext.save()
        selectedChapter = chapter
    }
}

struct VolumeSection: View {
    @Environment(\.modelContext) private var modelContext
    let volume: Volume
    @Binding var selectedChapter: Chapter?
    let isExpanded: Bool
    let onToggle: () -> Void
    
    @State private var isRenaming = false
    @State private var renameText = ""
    
    private var sortedChapters: [Chapter] {
        (volume.chapters ?? []).sorted { $0.order < $1.order }
    }
    
    var body: some View {
        Section {
            if isExpanded {
                ForEach(sortedChapters) { chapter in
                    ChapterRow(chapter: chapter, selectedChapter: $selectedChapter)
                        .tag(chapter)
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
                
                if isRenaming {
                    TextField("卷名", text: $renameText, onCommit: {
                        volume.title = renameText.isEmpty ? volume.title : renameText
                        volume.updatedAt = Date()
                        try? modelContext.save()
                        isRenaming = false
                    })
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 150)
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
                        modelContext.delete(volume)
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                onToggle()
            }
        }
    }
    
    private func addChapter() {
        let order = sortedChapters.count
        let chapter = Chapter(title: "第\(order + 1)章", order: order)
        chapter.volume = volume
        modelContext.insert(chapter)
        try? modelContext.save()
        selectedChapter = chapter
    }
    
    private func deleteChapters(at indexSet: IndexSet) {
        for index in indexSet {
            let chapter = sortedChapters[index]
            if selectedChapter?.id == chapter.id {
                selectedChapter = nil
            }
            modelContext.delete(chapter)
        }
        try? modelContext.save()
    }
    
    private func moveChapters(from source: IndexSet, to destination: Int) {
        var chapters = sortedChapters
        chapters.move(fromOffsets: source, toOffset: destination)
        for (index, chapter) in chapters.enumerated() {
            chapter.order = index
        }
        try? modelContext.save()
    }
}

struct ChapterRow: View {
    @Environment(\.modelContext) private var modelContext
    let chapter: Chapter
    @Binding var selectedChapter: Chapter?
    
    @State private var isRenaming = false
    @State private var renameText = ""
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            if isRenaming {
                TextField("章节名", text: $renameText, onCommit: {
                    chapter.title = renameText.isEmpty ? chapter.title : renameText
                    chapter.updatedAt = Date()
                    try? modelContext.save()
                    isRenaming = false
                })
                .textFieldStyle(.plain)
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
                    Button(status.rawValue) {
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
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("重命名") {
                renameText = chapter.title
                isRenaming = true
            }
            Divider()
            Button("删除", role: .destructive) {
                if selectedChapter?.id == chapter.id {
                    selectedChapter = nil
                }
                modelContext.delete(chapter)
                try? modelContext.save()
            }
        }
    }
    
    private var statusColor: Color {
        switch chapter.chapterStatus {
        case .draft: return .gray
        case .revising: return .orange
        case .completed: return .green
        case .archived: return .blue
        }
    }
}

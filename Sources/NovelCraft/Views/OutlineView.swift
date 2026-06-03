import SwiftUI
import SwiftData

/// 大纲视图：上半部分为整本书的大纲编辑框，下半部分为按卷划分的细纲。
struct OutlineView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project
    
    /// 是否正在添加卷大纲
    @State private var isAddingVolumeOutline = false
    
    /// 整本书的大纲
    @State private var bookOutlineText: String = ""
    
    /// 卷大纲节点：parent == nil 的顶层节点，按 order 排序
    private var volumeOutlines: [OutlineNode] {
        project.outlineNodes
            .filter { $0.parent == nil }
            .sorted { $0.order < $1.order }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 上半部分：整本书的大纲
            bookOutlineSection
            
            Divider()
            
            // 下半部分：按卷划分的细纲
            detailedOutlineSection
        }
    }
    
    // MARK: - 整本书的大纲
    
    private var bookOutlineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("整本书的大纲")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            TextEditor(text: $bookOutlineText)
                .font(.body)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .frame(minHeight: 120, maxHeight: 200)
                .onChange(of: bookOutlineText) { _, newValue in
                    project.bookOutline = newValue
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
        }
        .onAppear {
            bookOutlineText = project.bookOutline
        }
    }
    
    // MARK: - 细纲
    
    private var detailedOutlineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("细纲")
                    .font(.headline)
                Spacer()
                Button {
                    isAddingVolumeOutline = true
                } label: {
                    Label("添加卷大纲", systemImage: "plus.rectangle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: []) {
                    if volumeOutlines.isEmpty {
                        emptyVolumeState
                    } else {
                        ForEach(volumeOutlines) { volumeNode in
                            VolumeOutlineSection(volumeNode: volumeNode, project: project)
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $isAddingVolumeOutline) {
            VolumeOutlineEditView(project: project, volumeNode: nil)
        }
    }
    
    private var emptyVolumeState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 32))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("暂无卷大纲")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("点击右上角按钮添加卷大纲")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(.vertical, 20)
    }
}

// MARK: - 卷大纲区域

private struct VolumeOutlineSection: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var volumeNode: OutlineNode
    let project: Project
    
    @State private var isAddingDetail = false
    @State private var isEditingVolume = false
    
    /// 该卷下的具体细纲（子节点）
    private var detailNodes: [OutlineNode] {
        volumeNode.children.sorted { $0.order < $1.order }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 卷大纲头部
            HStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .foregroundStyle(Color.accentColor)
                Text(volumeNode.title.isEmpty ? "未命名卷大纲" : volumeNode.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Menu {
                    Button("编辑") {
                        isEditingVolume = true
                    }
                    Button("添加具体细纲") {
                        isAddingDetail = true
                    }
                    Divider()
                    Button("删除", role: .destructive) {
                        deleteVolumeNode()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
            }
            
            // 卷大纲内容
            if !volumeNode.content.isEmpty {
                Text(volumeNode.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            
            // 具体细纲列表
            if !detailNodes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(detailNodes) { detail in
                        DetailOutlineRow(detailNode: detail, volumeNode: volumeNode)
                    }
                }
                .padding(.leading, 12)
                .padding(.top, 4)
            }
            
            // 添加细纲按钮
            Button {
                isAddingDetail = true
            } label: {
                Label("添加具体细纲", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .padding(.leading, 12)
        }
        .padding()
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(.secondarySystemBackground))
        #endif
        .cornerRadius(10)
        .sheet(isPresented: $isAddingDetail) {
            DetailOutlineEditView(volumeNode: volumeNode, detailNode: nil)
        }
        .sheet(isPresented: $isEditingVolume) {
            VolumeOutlineEditView(project: project, volumeNode: volumeNode)
        }
    }
    
    private func deleteVolumeNode() {
        BlockRefEngine.deleteRefs(for: volumeNode.id, context: modelContext)
        modelContext.delete(volumeNode)
        try? modelContext.save()
    }
}

// MARK: - 具体细纲行

private struct DetailOutlineRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var detailNode: OutlineNode
    let volumeNode: OutlineNode
    
    @State private var isEditing = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(detailNode.title.isEmpty ? "未命名细纲" : detailNode.title)
                    .font(.caption)
                    .fontWeight(.medium)
                if !detailNode.content.isEmpty {
                    Text(detailNode.content)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button {
                isEditing = true
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $isEditing) {
            DetailOutlineEditView(volumeNode: volumeNode, detailNode: detailNode)
        }
    }
}

// MARK: - 卷大纲编辑视图

private struct VolumeOutlineEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    let volumeNode: OutlineNode?
    
    @State private var title = ""
    @State private var content = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("标题") {
                    TextField("卷名", text: $title)
                }
                Section("内容") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(volumeNode == nil ? "添加卷大纲" : "编辑卷大纲")
            .formToolbar(
                isSaveDisabled: title.isEmpty,
                onSave: save,
                onDelete: volumeNode != nil ? { delete() } : nil
            )
        }
        .frame(minWidth: 450, minHeight: 350)
        .onAppear {
            if let node = volumeNode {
                title = node.title
                content = node.content
            }
        }
    }
    
    private func save() {
        if let node = volumeNode {
            node.title = title
            node.content = content
            node.updatedAt = Date()
        } else {
            let order = project.outlineNodes.filter { $0.parent == nil }.count
            let node = OutlineNode(title: title, content: content, order: order, nodeType: "volume")
            node.project = project
            modelContext.insert(node)
        }
        try? modelContext.save()
        dismiss()
    }
    
    private func delete() {
        if let node = volumeNode {
            BlockRefEngine.deleteRefs(for: node.id, context: modelContext)
            modelContext.delete(node)
            try? modelContext.save()
        }
        dismiss()
    }
}

// MARK: - 具体细纲编辑视图

private struct DetailOutlineEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let volumeNode: OutlineNode
    let detailNode: OutlineNode?
    
    @State private var title = ""
    @State private var content = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("标题") {
                    TextField("细纲标题", text: $title)
                }
                Section("内容") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(detailNode == nil ? "添加具体细纲" : "编辑具体细纲")
            .formToolbar(
                isSaveDisabled: title.isEmpty,
                onSave: save,
                onDelete: detailNode != nil ? { delete() } : nil
            )
        }
        .frame(minWidth: 450, minHeight: 350)
        .onAppear {
            if let node = detailNode {
                title = node.title
                content = node.content
            }
        }
    }
    
    private func save() {
        if let node = detailNode {
            node.title = title
            node.content = content
            node.updatedAt = Date()
        } else {
            let order = volumeNode.children.count
            let node = OutlineNode(title: title, content: content, order: order, nodeType: "detail")
            node.project = volumeNode.project
            node.parent = volumeNode
            modelContext.insert(node)
        }
        try? modelContext.save()
        dismiss()
    }
    
    private func delete() {
        if let node = detailNode {
            BlockRefEngine.deleteRefs(for: node.id, context: modelContext)
            modelContext.delete(node)
            try? modelContext.save()
        }
        dismiss()
    }
}

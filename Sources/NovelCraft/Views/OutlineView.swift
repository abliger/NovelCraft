import SwiftUI
import SwiftData

/// 大纲视图：展示项目的树形大纲结构，支持添加、编辑和删除节点
struct OutlineView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project?
    
    /// 是否正在添加新节点（用于控制新建节点弹窗）
    @State private var isAddingNode = false
    
    /// 根节点列表：筛选出当前项目下没有父节点的大纲节点，并按 order 排序
    private var rootNodes: [OutlineNode] {
        (project?.outlineNodes ?? [])
            .filter { $0.parent == nil }
            .sorted { $0.order < $1.order }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("大纲")
                    .font(.headline)
                Spacer()
                Button {
                    addNode()
                } label: {
                    Image(systemName: "plus.rectangle")
                }
                .help("添加节点")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 12, pinnedViews: []) {
                    ForEach(rootNodes) { node in
                        OutlineCard(node: node, level: 0)
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $isAddingNode) {
            NodeEditView(project: project, node: nil, parent: nil)
        }
    }
    
    /// 打开新建节点的弹窗
    private func addNode() {
        isAddingNode = true
    }
}

/// 大纲卡片视图：递归渲染单个大纲节点及其子节点，支持展开/收起和编辑操作
struct OutlineCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var node: OutlineNode
    let level: Int
    
    /// 当前节点是否展开子节点
    @State private var isExpanded = true
    /// 是否正在添加子节点（用于控制添加子节点弹窗）
    @State private var isAddingChild = false
    /// 是否显示编辑弹窗
    @State private var showingEdit = false
    
    /// 子节点列表：将当前节点的 children 按 order 排序
    private var children: [OutlineNode] {
        (node.children ?? []).sorted { $0.order < $1.order }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if !children.isEmpty {
                    Button {
                        isExpanded.toggle()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 12)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.title.isEmpty ? "未命名节点" : node.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if !node.content.isEmpty {
                        Text(node.content)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Menu {
                    Button("添加子节点") {
                        isAddingChild = true
                    }
                    Button("编辑") {
                        showingEdit = true
                    }
                    Divider()
                    Button("删除", role: .destructive) {
                        BlockRefEngine.deleteRefs(for: node.id, context: modelContext)
                        modelContext.delete(node)
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
            }
            .padding()
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(.secondarySystemBackground))
            #endif
            .cornerRadius(10)
            .padding(.leading, CGFloat(level * 20))
            
            if isExpanded {
                ForEach(children) { child in
                    OutlineCard(node: child, level: level + 1)
                }
            }
        }
        .sheet(isPresented: $isAddingChild) {
            NodeEditView(project: nil, node: nil, parent: node)
        }
        .sheet(isPresented: $showingEdit) {
            NodeEditView(project: nil, node: node, parent: node.parent)
        }
    }
}

/// 节点编辑视图：用于新建或编辑大纲节点，包含标题、类型和内容
struct NodeEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: Project?
    let node: OutlineNode?
    let parent: OutlineNode?
    
    /// 节点标题输入
    @State private var title = ""
    /// 节点内容输入
    @State private var content = ""
    /// 节点类型（card / chapter / plot / arc）
    @State private var nodeType = "card"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                    Picker("类型", selection: $nodeType) {
                        Text("卡片").tag("card")
                        Text("章节").tag("chapter")
                        Text("情节点").tag("plot")
                        Text("角色弧").tag("arc")
                    }
                }
                
                Section("内容") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(node == nil ? "新建节点" : "编辑节点")
            .formToolbar(
                isSaveDisabled: false,
                onSave: save,
                onDelete: node != nil ? { deleteNode() } : nil
            )
        }
        .frame(minWidth: 450, minHeight: 350)
        .onAppear {
            if let n = node {
                title = n.title
                content = n.content
                nodeType = n.nodeType
            }
        }
    }
    
    /// 删除节点：清理双向链接引用并删除对象。
    private func deleteNode() {
        if let n = node {
            BlockRefEngine.deleteRefs(for: n.id, context: modelContext)
            modelContext.delete(n)
            try? modelContext.save()
        }
    }
    
    /// 保存节点：如果是编辑则更新现有节点，否则创建新节点并插入上下文
    private func save() {
        if let n = node {
            n.title = title
            n.content = content
            n.nodeType = nodeType
            n.updatedAt = Date()
        } else {
            let order: Int
            if let p = parent {
                order = (p.children ?? []).count
            } else {
                order = (project?.outlineNodes ?? []).filter { $0.parent == nil }.count
            }
            
            let n = OutlineNode(title: title, content: content, order: order, nodeType: nodeType)
            n.project = project ?? parent?.project
            
            // 循环引用检测：确保不将节点设为自身的后代
            if let p = parent, wouldCreateCycle(node: n, newParent: p) {
                n.parent = nil
            } else {
                n.parent = parent
            }
            
            modelContext.insert(n)
        }
        try? modelContext.save()
        dismiss()
    }
    
    /// 检测将节点设置为 newParent 的子节点是否会形成循环引用。
    private func wouldCreateCycle(node: OutlineNode, newParent: OutlineNode) -> Bool {
        var current: OutlineNode? = newParent
        while let c = current {
            if c.id == node.id { return true }
            current = c.parent
        }
        return false
    }
}

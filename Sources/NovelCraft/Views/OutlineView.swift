import SwiftUI
import SwiftData

struct OutlineView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project?
    
    @State private var isAddingNode = false
    @State private var selectedNode: OutlineNode?
    
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
        .sheet(item: $selectedNode) { node in
            NodeEditView(project: project, node: node, parent: nil)
        }
        .sheet(isPresented: $isAddingNode) {
            NodeEditView(project: project, node: nil, parent: nil)
        }
    }
    
    private func addNode() {
        isAddingNode = true
    }
}

struct OutlineCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var node: OutlineNode
    let level: Int
    
    @State private var isExpanded = true
    @State private var isAddingChild = false
    @State private var showingEdit = false
    
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
            .background(Color(NSColor.controlBackgroundColor))
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

struct NodeEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: Project?
    let node: OutlineNode?
    let parent: OutlineNode?
    
    @State private var title = ""
    @State private var content = ""
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                }
                if node != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("删除", role: .destructive) {
                            if let n = node {
                                modelContext.delete(n)
                                try? modelContext.save()
                            }
                            dismiss()
                        }
                    }
                }
            }
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
            n.parent = parent
            modelContext.insert(n)
        }
        try? modelContext.save()
        dismiss()
    }
}

import SwiftUI
import SwiftData

/// 便签列表视图：以网格形式展示项目的便签，支持搜索、添加、编辑和置顶操作
struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project?
    
    /// 是否正在添加新便签（用于控制新建便签弹窗）
    @State private var isAddingNote = false
    /// 搜索文本，用于过滤便签列表
    @State private var searchText = ""
    
    /// 当前显示的便签列表：按置顶状态和时间排序，并支持按搜索文本过滤
    private var notes: [Note] {
        let all = (project?.notes ?? []).sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.updatedAt > $1.updatedAt
        }
        if searchText.isEmpty { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    /// 便签可选颜色列表，name 用于与模型存储的值匹配
    private let colors: [(name: String, color: Color)] = [
        ("yellow", .yellow),
        ("red", .red),
        ("green", .green),
        ("blue", .blue),
        ("purple", .purple),
        ("orange", .orange),
        ("pink", .pink),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SearchField(text: $searchText)
                Spacer()
                Button {
                    isAddingNote = true
                } label: {
                    Image(systemName: "note.text.badge.plus")
                }
                .help("添加便签")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                    ForEach(notes) { note in
                        NoteCard(note: note, color: noteColor(note.color))
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $isAddingNote) {
            NoteEditView(project: project, note: nil)
        }
    }
    
    /// 根据颜色名称返回对应的 Color，若未匹配则默认返回黄色
    private func noteColor(_ name: String) -> Color {
        colors.first { $0.name == name }?.color ?? .yellow
    }
}

/// 便签卡片视图：展示单个便签的标题、内容和更新时间，支持点击编辑和置顶切换
struct NoteCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var note: Note
    let color: Color
    
    /// 是否显示编辑弹窗
    @State private var showingEdit = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(color.opacity(0.8))
                }
                Spacer()
                Button {
                    withAnimation {
                        note.isPinned.toggle()
                        note.updatedAt = Date()
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: note.isPinned ? "pin.fill" : "pin")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            
            Text(note.title.isEmpty ? "无标题" : note.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            if !note.content.isEmpty {
                Text(note.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            
            Spacer()
            
            Text(note.updatedAt, style: .date)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(height: 160)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            showingEdit = true
        }
        .contextMenu {
            Button(note.isPinned ? "取消置顶" : "置顶") {
                note.isPinned.toggle()
                note.updatedAt = Date()
                try? modelContext.save()
            }
            Divider()
            Button("删除", role: .destructive) {
                modelContext.delete(note)
                try? modelContext.save()
            }
        }
        .sheet(isPresented: $showingEdit) {
            NoteEditView(project: nil, note: note)
        }
    }
}

/// 便签编辑视图：用于新建或编辑便签，包含标题、颜色选择和内容编辑
struct NoteEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: Project?
    let note: Note?
    
    /// 便签标题输入
    @State private var title = ""
    /// 便签内容输入
    @State private var content = ""
    /// 当前选中的颜色名称
    @State private var selectedColor = "yellow"
    
    /// 编辑视图中的可选颜色列表
    private let colors = [
        ("yellow", Color.yellow),
        ("red", Color.red),
        ("green", Color.green),
        ("blue", Color.blue),
        ("purple", Color.purple),
        ("orange", Color.orange),
        ("pink", Color.pink),
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                    
                    HStack(spacing: 12) {
                        ForEach(colors, id: \.0) { name, color in
                            Circle()
                                .fill(color)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == name ? Color.primary : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedColor = name
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("内容") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(note == nil ? "新建便签" : "编辑便签")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                }
                if note != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("删除", role: .destructive) {
                            if let n = note {
                                modelContext.delete(n)
                                try? modelContext.save()
                            }
                            dismiss()
                        }
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 350)
        .onAppear {
            if let n = note {
                title = n.title
                content = n.content
                selectedColor = n.color
            }
        }
    }
    
    /// 保存便签：如果是编辑则更新现有便签，否则创建新便签并插入上下文
    private func save() {
        if let n = note {
            n.title = title
            n.content = content
            n.color = selectedColor
            n.updatedAt = Date()
        } else {
            let note = Note(title: title, content: content, color: selectedColor)
            note.project = project
            modelContext.insert(note)
        }
        try? modelContext.save()
        dismiss()
    }
}

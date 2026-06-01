import SwiftUI
import SwiftData

/// 待办清单官方内置插件。
///
/// 为每个项目提供独立的任务管理面板，支持增删改查、完成状态切换与拖拽排序。
@MainActor
final class TodoListPlugin: NovelCraftPlugin, SidebarPanelContributor {
    let id = "com.novelcraft.plugins.todolist"
    let name = "待办清单"
    let description = "为当前项目管理写作任务与待办事项"
    let version = "1.0.0"
    let author = "NovelCraft Team"
    var isEnabled: Bool = true
    
    private weak var context: PluginContext?
    
    var sidebarPanels: [PluginSidebarPanel] {
        [
            PluginSidebarPanel(
                id: "\(id).panel",
                title: "待办",
                icon: "checklist"
            ) { [weak self] in
                guard let self = self, let ctx = self.context else {
                    return AnyView(EmptyView())
                }
                return AnyView(TodoListPluginView(context: ctx))
            }
        ]
    }
    
    func setup(context: PluginContext) {
        self.context = context
    }
    
    func teardown() {
        context = nil
    }
}

// MARK: - 插件视图

/// 待办清单插件视图。
private struct TodoListPluginView: View {
    @Environment(\.modelContext) private var modelContext
    let context: PluginContext
    
    @State private var newTaskTitle = ""
    @State private var editTaskID: UUID?
    @State private var editText = ""
    @FocusState private var isInputFocused: Bool
    @FocusState private var isEditFocused: Bool
    
    /// 当前项目的待办事项（按 order 排序）
    private var todos: [TodoItem] {
        guard let project = context.currentProject else { return [] }
        let projectID = project.id
        let predicate = #Predicate<TodoItem> { $0.projectID == projectID }
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.order)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 输入栏
            HStack(spacing: 8) {
                TextField("添加待办事项…", text: $newTaskTitle)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .onSubmit {
                        addTodo()
                    }
                
                Button {
                    addTodo()
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                .help("添加")
            }
            .padding()
            
            Divider()
            
            // 待办列表
            if todos.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("暂无待办事项")
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(todos) { todo in
                        TodoRow(
                            todo: todo,
                            isEditing: editTaskID == todo.id,
                            editText: $editText,
                            isEditFocused: $isEditFocused,
                            onToggle: { toggleTodo(todo) },
                            onBeginEdit: { beginEdit(todo) },
                            onCommitEdit: { commitEdit(todo) },
                            onDelete: { deleteTodo(todo) }
                        )
                    }
                    .onMove(perform: moveTodos)
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - 操作
    
    private func addTodo() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, let project = context.currentProject else { return }
        
        let maxOrder = todos.map(\.order).max() ?? -1
        let todo = TodoItem(title: title, projectID: project.id, order: maxOrder + 1)
        modelContext.insert(todo)
        try? modelContext.save()
        
        newTaskTitle = ""
        isInputFocused = true
    }
    
    private func toggleTodo(_ todo: TodoItem) {
        todo.isCompleted.toggle()
        todo.completedAt = todo.isCompleted ? Date() : nil
        try? modelContext.save()
    }
    
    private func beginEdit(_ todo: TodoItem) {
        editTaskID = todo.id
        editText = todo.title
        isEditFocused = true
    }
    
    private func commitEdit(_ todo: TodoItem) {
        let trimmed = editText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            todo.title = trimmed
            try? modelContext.save()
        }
        editTaskID = nil
    }
    
    private func deleteTodo(_ todo: TodoItem) {
        modelContext.delete(todo)
        try? modelContext.save()
    }
    
    private func moveTodos(from source: IndexSet, to destination: Int) {
        var updated = todos
        updated.move(fromOffsets: source, toOffset: destination)
        for (index, todo) in updated.enumerated() {
            todo.order = index
        }
        try? modelContext.save()
    }
}

// MARK: - 单行视图

private struct TodoRow: View {
    let todo: TodoItem
    let isEditing: Bool
    @Binding var editText: String
    var isEditFocused: FocusState<Bool>.Binding
    let onToggle: () -> Void
    let onBeginEdit: () -> Void
    let onCommitEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var lastTapTime: Date?
    
    var body: some View {
        HStack(spacing: 8) {
            // 完成按钮
            Button {
                withAnimation { onToggle() }
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 20)
            
            // 标题 / 编辑框
            if isEditing {
                TextField("", text: $editText)
                    .textFieldStyle(.roundedBorder)
                    .focused(isEditFocused)
                    .onSubmit {
                        onCommitEdit()
                    }
            } else {
                Text(todo.title)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    .lineLimit(1)
                    .onTapGesture {
                        handleTap()
                    }
            }
            
            Spacer()
            
            // 删除按钮
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(todo.isCompleted ? 1.0 : 0.6)
        }
        .padding(.vertical, 4)
    }
    
    private func handleTap() {
        if let last = lastTapTime, Date().timeIntervalSince(last) < 0.4 {
            onBeginEdit()
            lastTapTime = nil
        } else {
            lastTapTime = Date()
        }
    }
}

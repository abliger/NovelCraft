import SwiftUI

#if os(macOS)

/// 插件级待办事项数据模型（与项目级 SwiftData TodoItem 区分）。
struct TodoTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

/// 待办清单视图，提供任务的增删改查与完成状态切换。
struct TodoListView: View {
    @AppStorage("todoListItems") private var todoData: Data = Data()
    @State private var items: [TodoTask] = []
    @State private var newTaskTitle: String = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            if items.isEmpty {
                emptyState
            } else {
                taskList
            }
            
            Divider()
            
            inputBar
        }
        .frame(width: 360, height: 500)
        .onAppear(perform: loadItems)
        .onChange(of: todoData) { _, _ in
            loadItems()
        }
    }
    
    // MARK: - 子视图
    
    private var header: some View {
        HStack {
            Image(systemName: "checklist")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Text("待办清单")
                .font(.title3)
                .fontWeight(.bold)
            Spacer()
            
            let completed = items.filter(\.isCompleted).count
            if completed > 0 {
                Button("清除已完成") {
                    clearCompleted()
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
        }
        .padding()
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist.unchecked")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("暂无待办事项")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("在下方输入框添加新任务")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var taskList: some View {
        List {
            ForEach($items) { $item in
                TodoRow(item: $item, onToggle: { saveItems() })
            }
            .onDelete(perform: deleteItems)
        }
        .listStyle(.plain)
    }
    
    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("添加新任务...", text: $newTaskTitle)
                .textFieldStyle(.roundedBorder)
                .focused($isInputFocused)
                .onSubmit {
                    addItem()
                }
            
            Button {
                addItem()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }
    
    // MARK: - 数据操作
    
    private func loadItems() {
        if let decoded = try? JSONDecoder().decode([TodoTask].self, from: todoData) {
            items = decoded.sorted { ($0.isCompleted ? 1 : 0) < ($1.isCompleted ? 1 : 0) }
        } else {
            items = []
        }
    }
    
    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            todoData = encoded
        }
    }
    
    private func addItem() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = TodoTask(title: trimmed)
        items.insert(item, at: 0)
        newTaskTitle = ""
        saveItems()
    }
    
    private func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        saveItems()
    }
    
    private func clearCompleted() {
        items.removeAll { $0.isCompleted }
        saveItems()
    }
}

// MARK: - 单行任务视图

struct TodoRow: View {
    @Binding var item: TodoTask
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Button {
                item.isCompleted.toggle()
                onToggle()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isCompleted ? Color.green : Color.secondary)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
            
            Text(item.title)
                .font(.body)
                .strikethrough(item.isCompleted)
                .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#endif

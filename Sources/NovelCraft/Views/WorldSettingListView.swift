import SwiftUI
import SwiftData

struct WorldSettingListView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project?
    
    @State private var isAddingSetting = false
    @State private var searchText = ""
    @State private var selectedCategory = "全部"
    @State private var selectedSetting: WorldSetting?
    
    private var categories: [String] {
        var cats = Set((project?.worldSettings ?? []).map { $0.category })
        cats.insert("全部")
        return Array(cats).sorted()
    }
    
    private var settings: [WorldSetting] {
        let all = (project?.worldSettings ?? []).sorted { $0.order < $1.order }
        var filtered = all
        if selectedCategory != "全部" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        if searchText.isEmpty { return filtered }
        return filtered.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SearchField(text: $searchText)
                Spacer()
                Picker("分类", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .frame(width: 120)
                Button {
                    isAddingSetting = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("添加设定")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            List(settings, selection: $selectedSetting) { setting in
                SettingRow(setting: setting)
                    .tag(setting)
            }
            .listStyle(.plain)
        }
        .sheet(isPresented: $isAddingSetting) {
            SettingEditView(project: project, setting: nil)
        }
        .sheet(item: $selectedSetting) { setting in
            SettingEditView(project: project, setting: setting)
        }
    }
}

struct SettingRow: View {
    let setting: WorldSetting
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(setting.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(setting.category)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .cornerRadius(4)
            }
            
            if !setting.content.isEmpty {
                Text(setting.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SettingEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: Project?
    let setting: WorldSetting?
    
    @State private var category = "未分类"
    @State private var title = ""
    @State private var content = ""
    
    private let presetCategories = ["地理", "历史", "文化", "魔法/科技", "种族", "势力", "物品", "其他"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                    Picker("分类", selection: $category) {
                        ForEach(presetCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }
                
                Section("内容") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(setting == nil ? "新建设定" : "编辑设定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                }
                if setting != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("删除", role: .destructive) {
                            if let s = setting {
                                modelContext.delete(s)
                                try? modelContext.save()
                            }
                            dismiss()
                        }
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            if let s = setting {
                category = s.category
                title = s.title
                content = s.content
            }
        }
    }
    
    private func save() {
        if let s = setting {
            s.category = category
            s.title = title
            s.content = content
            s.updatedAt = Date()
        } else {
            let order = (project?.worldSettings ?? []).count
            let s = WorldSetting(category: category, title: title, content: content, order: order)
            s.project = project
            modelContext.insert(s)
        }
        try? modelContext.save()
        dismiss()
    }
}

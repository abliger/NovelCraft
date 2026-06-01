import SwiftUI
import SwiftData

/// 世界观设定列表视图：展示项目下的世界观设定，支持按分类筛选、搜索、新建与编辑
struct WorldSettingListView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project?
    
    // MARK: - 状态变量
    
    /// 控制新建设定弹窗的显示状态
    @State private var isAddingSetting = false
    /// 搜索框输入文本，用于按标题或内容过滤设定
    @State private var searchText = ""
    /// 当前选中的分类筛选条件，默认"全部"
    @State private var selectedCategory = "全部"
    /// 当前选中的设定项，非 nil 时弹出编辑弹窗
    @State private var selectedSetting: WorldSetting?
    
    // MARK: - 计算属性
    
    /// 所有可用的分类集合，包含项目中已有分类及默认"全部"选项
    private var categories: [String] {
        var cats = Set((project?.worldSettings ?? []).map { $0.category })
        cats.insert("全部")
        return Array(cats).sorted()
    }
    
    /// 根据当前分类筛选与搜索文本过滤后的设定列表，按 order 排序
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

/// 设定列表中的单行视图：显示标题、分类标签及内容摘要
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

/// 设定编辑弹窗视图：用于新建或编辑世界观设定，包含标题、分类与内容编辑
struct SettingEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: Project?
    /// 当前编辑的设定对象，nil 表示新建
    let setting: WorldSetting?
    
    // MARK: - 表单状态
    
    /// 分类输入/选择值
    @State private var category = "未分类"
    /// 标题输入值
    @State private var title = ""
    /// 内容输入值
    @State private var content = ""
    
    /// 预设分类选项，用于 Picker 快速选择
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
            .formToolbar(
                isSaveDisabled: title.isEmpty,
                onSave: save,
                onDelete: setting != nil ? { deleteSetting() } : nil
            )
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            // 编辑模式下将已有设定数据加载到表单状态
            if let s = setting {
                category = s.category
                title = s.title
                content = s.content
            }
        }
    }
    
    /// 删除设定：清理双向链接引用并删除对象。
    private func deleteSetting() {
        if let s = setting {
            BlockRefEngine.deleteRefs(for: s.id, context: modelContext)
            modelContext.delete(s)
            try? modelContext.save()
        }
    }
    
    /// 保存设定：编辑时更新现有对象，新建时插入新对象并关联项目
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

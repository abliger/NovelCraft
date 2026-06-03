import SwiftUI
import SwiftData

/// 角色列表视图，展示项目中的所有角色，支持搜索、新增与编辑。
struct CharacterListView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project?
    
    @State private var isAddingCharacter = false
    @State private var searchText = ""
    @State private var selectedCharacter: Character?
    
    /// 按 order 排序并根据搜索文本过滤后的角色列表
    private var characters: [Character] {
        let all = (project?.characters ?? []).sorted { $0.order < $1.order }
        if searchText.isEmpty { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.aliases.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SearchField(text: $searchText)
                Spacer()
                Button {
                    isAddingCharacter = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .help("添加角色")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            List(characters, selection: $selectedCharacter) { character in
                CharacterRow(character: character)
                    .tag(character)
            }
            .listStyle(.plain)
        }
        .sheet(isPresented: $isAddingCharacter) {
            CharacterEditView(project: project, character: nil)
        }
        .sheet(item: $selectedCharacter) { character in
            CharacterEditView(project: project, character: character)
        }
    }
}

/// 单行角色视图，展示角色头像、姓名、别名与基本信息。
struct CharacterRow: View {
    let character: Character
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(character.name.prefix(1)))
                        .font(.headline)
                        .foregroundStyle(.purple)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(character.name.isEmpty ? "未命名角色" : character.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !character.aliases.isEmpty {
                    Text(character.aliases)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    if !character.gender.isEmpty {
                        Label(character.gender, systemImage: "person")
                            .font(.caption2)
                    }
                    if !character.age.isEmpty {
                        Label(character.age, systemImage: "calendar")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

/// 角色编辑/新建弹窗，包含角色的完整信息表单。
struct CharacterEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: Project?
    let character: Character?
    
    @State private var name = ""
    @State private var aliases = ""
    @State private var gender = ""
    @State private var age = ""
    @State private var appearance = ""
    @State private var personality = ""
    @State private var background = ""
    @State private var goals = ""
    @State private var fate = ""
    @State private var relationships = ""
    @State private var notes = ""
    
    private let genders = ["男", "女", "其他", "未知"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("姓名", text: $name)
                    TextField("别名", text: $aliases)
                    Picker("性别", selection: $gender) {
                        ForEach(genders, id: \.self) { g in
                            Text(g).tag(g)
                        }
                    }
                    TextField("年龄", text: $age)
                }
                
                Section("外貌") {
                    TextEditor(text: $appearance)
                        .frame(height: 80)
                }
                
                Section("性格") {
                    TextEditor(text: $personality)
                        .frame(height: 80)
                }
                
                Section("背景") {
                    TextEditor(text: $background)
                        .frame(height: 80)
                }
                
                Section("目标") {
                    TextEditor(text: $goals)
                        .frame(height: 80)
                }
                
                Section("命运") {
                    TextEditor(text: $fate)
                        .frame(height: 80)
                }
                
                Section("关系") {
                    TextEditor(text: $relationships)
                        .frame(height: 80)
                }
                
                Section("备注") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(character == nil ? "新建角色" : "编辑角色")
            .formToolbar(
                isSaveDisabled: name.isEmpty,
                onSave: save,
                onDelete: character != nil ? { deleteCharacter() } : nil
            )
        }
        .frame(minWidth: 500, minHeight: 600)
        .onAppear {
            if let char = character {
                name = char.name
                aliases = char.aliases
                gender = char.gender
                age = char.age
                appearance = char.appearance
                personality = char.personality
                background = char.background
                goals = char.goals
                fate = char.fate
                relationships = char.relationships
                notes = char.notes
            }
        }
    }
    
    /// 删除角色：清理双向链接引用并删除对象。
    private func deleteCharacter() {
        if let char = character {
            BlockRefEngine.deleteRefs(for: char.id, context: modelContext)
            modelContext.delete(char)
            try? modelContext.save()
        }
    }
    
    /// 保存角色信息：更新现有角色或创建新角色。
    private func save() {
        if let char = character {
            char.name = name
            char.aliases = aliases
            char.gender = gender
            char.age = age
            char.appearance = appearance
            char.personality = personality
            char.background = background
            char.goals = goals
            char.fate = fate
            char.relationships = relationships
            char.notes = notes
            char.updatedAt = Date()
        } else {
            let order = (project?.characters ?? []).count
            let char = Character(
                name: name,
                aliases: aliases,
                gender: gender,
                age: age,
                appearance: appearance,
                personality: personality,
                background: background,
                goals: goals,
                fate: fate,
                relationships: relationships,
                notes: notes,
                order: order
            )
            char.project = project
            modelContext.insert(char)
        }
        try? modelContext.save()
        dismiss()
    }
}

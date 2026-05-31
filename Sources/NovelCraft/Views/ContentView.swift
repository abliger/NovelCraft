import SwiftUI
import SwiftData

/// 侧边栏标签枚举，对应主界面的五个功能模块。
enum SidebarTab: String, CaseIterable {
    case chapters = "章节"
    case characters = "角色"
    case world = "世界观"
    case outline = "大纲"
    case notes = "便签"
    
    /// 每个标签对应的系统图标名称
    var icon: String {
        switch self {
        case .chapters: return "list.bullet.rectangle"
        case .characters: return "person.2"
        case .world: return "globe"
        case .outline: return "diagram.project"
        case .notes: return "note.text"
        }
    }
}

/// 应用主界面视图，负责管理项目选择、侧边栏导航、编辑器展示与全局工具栏。
struct ContentView: View {
    /// 当前选中的项目 ID（nil 表示处于项目列表）
    @State private var selectedProjectID: UUID? = nil
    /// 当前项目的数据库容器
    @State private var projectContainer: ModelContainer?
    /// 当前项目的数据库实例
    @State private var currentProject: Project?
    
    /// 当前侧边栏选中的标签
    @State private var selectedTab: SidebarTab = .chapters
    /// 当前选中的章节
    @State private var selectedChapter: Chapter? = nil
    /// 是否进入专注模式
    @State private var isFocusMode = false
    /// 是否显示设置面板
    @State private var isShowingSettings = false
    /// 是否显示导出面板
    @State private var isShowingExport = false
    
    var body: some View {
        Group {
            if isFocusMode, let project = currentProject, let chapter = selectedChapter {
                FocusModeView(
                    project: project,
                    chapter: chapter,
                    isFocusMode: $isFocusMode
                )
            } else if let container = projectContainer, let project = currentProject {
                mainInterface(project: project)
                    .modelContainer(container)
                    .id(selectedProjectID)
            } else {
                ProjectListView(selectedProjectID: $selectedProjectID)
            }
        }
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 600)
        #endif
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $isShowingExport) {
            if let project = currentProject {
                ExportView(project: project, chapter: selectedChapter)
            }
        }
        .onChange(of: selectedProjectID) { _, newValue in
            if let id = newValue {
                openProject(id: id)
            } else {
                closeProject()
            }
        }
    }
    
    /// 打开指定 ID 的项目数据库。
    private func openProject(id: UUID) {
        guard let meta = ProjectRegistry.shared.project(withID: id) else {
            selectedProjectID = nil
            return
        }
        
        let schema = Schema([
            Project.self,
            Volume.self,
            Chapter.self,
            StoryScene.self,
            Character.self,
            WorldSetting.self,
            OutlineNode.self,
            Note.self,
        ])
        
        let dbURL = URL(fileURLWithPath: meta.storagePath)
            .appendingPathComponent("NovelCraft.store")
        let config = ModelConfiguration(schema: schema, url: dbURL)
        
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            let context = container.mainContext
            
            let descriptor = FetchDescriptor<Project>()
            let dbProjects = try context.fetch(descriptor)
            
            if let project = dbProjects.first {
                // 同步注册表中的最新元数据到数据库
                syncMetaToProject(meta: meta, project: project, context: context)
                self.projectContainer = container
                self.currentProject = project
            } else {
                // 数据库中不存在 Project 记录（异常情况），新建一个
                let newProject = Project(
                    title: meta.title,
                    author: meta.author,
                    summary: meta.summary,
                    storagePath: meta.storagePath,
                    targetWordCount: meta.targetWordCount,
                    dailyWordGoal: meta.dailyWordGoal
                )
                context.insert(newProject)
                try context.save()
                self.projectContainer = container
                self.currentProject = newProject
            }
        } catch {
            print("打开项目失败: \(error)")
            selectedProjectID = nil
        }
    }
    
    /// 关闭当前项目，清理数据库容器，并将最新统计信息同步到注册表。
    private func closeProject() {
        syncProjectStats()
        projectContainer = nil
        currentProject = nil
        selectedChapter = nil
    }
    
    /// 将当前项目的字数统计同步到注册表。
    private func syncProjectStats() {
        guard let project = currentProject else { return }
        guard var meta = ProjectRegistry.shared.project(withID: project.id) else { return }
        meta.totalWordCount = project.totalWordCount
        meta.progressPercentage = project.progressPercentage
        meta.updatedAt = Date()
        ProjectRegistry.shared.updateProject(meta)
    }
    
    /// 将注册表中的元数据同步到项目数据库的 Project 实体。
    private func syncMetaToProject(meta: ProjectMeta, project: Project, context: ModelContext) {
        project.title = meta.title
        project.author = meta.author
        project.summary = meta.summary
        project.storagePath = meta.storagePath
        project.targetWordCount = meta.targetWordCount
        project.dailyWordGoal = meta.dailyWordGoal
        try? context.save()
    }
    
    /// 主编辑界面，包含侧边栏与详情区的 NavigationSplitView。
    @ViewBuilder
    private func mainInterface(project: Project) -> some View {
        NavigationSplitView {
            sidebar(project: project)
        } detail: {
            detailView(project: project)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation {
                        selectedProjectID = nil
                        selectedChapter = nil
                    }
                } label: {
                    Image(systemName: "books.vertical")
                }
                .help("返回项目列表")
            }
            
            ToolbarItem(placement: .principal) {
                Text(project.title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 280)
            }
            
            ToolbarItem {
                Button {
                    isFocusMode = true
                } label: {
                    Image(systemName: "lightbulb")
                }
                .help("专注模式 (⇧⌘F)")
                .disabled(selectedChapter == nil)
            }
            
            ToolbarItem {
                Button {
                    isShowingExport = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("导出")
            }
            
            ToolbarItem {
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gear")
                }
                .help("设置")
            }
        }
    }
    
    /// 侧边栏视图，包含分段选择器与对应功能模块列表。
    @ViewBuilder
    private func sidebar(project: Project) -> some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            switch selectedTab {
            case .chapters:
                ChapterTreeView(
                    project: project,
                    selectedChapter: $selectedChapter
                )
            case .characters:
                CharacterListView(project: project)
            case .world:
                WorldSettingListView(project: project)
            case .outline:
                OutlineView(project: project)
            case .notes:
                NoteListView(project: project)
            }
        }
    }
    
    /// 详情区视图，根据是否选中章节展示编辑器或空状态。
    @ViewBuilder
    private func detailView(project: Project) -> some View {
        if let chapter = selectedChapter {
            EditorView(
                project: project,
                chapter: chapter
            )
            .id(chapter.id)
        } else {
            EmptyEditorView(project: project)
        }
    }
}

/// 未选中章节时展示的占位视图，显示项目统计信息。
struct EmptyEditorView: View {
    let project: Project?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("选择一个章节开始写作")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            if let project = project {
                HStack(spacing: 30) {
                    StatCard(title: "总字数", value: "\(project.totalWordCount)")
                    StatCard(title: "目标字数", value: "\(project.targetWordCount)")
                    StatCard(title: "完成度", value: "\(Int(project.progressPercentage * 100))%")
                }
                .padding(.top, 20)
            }
        }
    }
}

/// 统计信息卡片，用于展示字数、目标等数值。
struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 100)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

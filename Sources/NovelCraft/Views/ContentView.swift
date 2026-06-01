import SwiftData
import SwiftUI

/// 右侧辅助面板标签枚举。
enum RightPanelTab: String, CaseIterable {
    case characters = "角色"
    case world = "世界观"
    case outline = "大纲"
    case notes = "便签"

    var icon: String {
        switch self {
        case .characters: return "person.2"
        case .world: return "globe"
        case .outline: return "list.bullet.indent"
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

    /// 右侧辅助边栏是否显示
    @State private var isRightSidebarVisible: Bool = false
    /// 是否显示电子表格
    @State private var isSpreadsheetActive: Bool = false
    /// 右侧辅助边栏当前选中的标签
    @State private var rightSidebarTab: RightPanelTab = .characters
    /// 当前选中的插件面板 ID
    @State private var selectedPluginPanelID: String? = nil
    /// 当前选中的章节
    @State private var selectedChapter: Chapter? = nil
    /// 是否进入专注模式
    @State private var isFocusMode = false
    #if os(iOS)
        /// 是否显示设置面板（iOS 通过 toolbar 按钮触发）
        @State private var isShowingSettings = false
    #endif
    /// 是否显示导出面板
    @State private var isShowingExport = false
    @State private var isShowingPluginManager = false

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
        #if os(iOS)
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
        #endif
        .sheet(isPresented: $isShowingExport) {
            if let project = currentProject {
                ExportView(project: project, chapter: selectedChapter)
            }
        }
        .sheet(isPresented: $isShowingPluginManager) {
            PluginSettingsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showPluginManager)) { _ in
            isShowingPluginManager = true
        }
        .onChange(of: selectedProjectID) { _, newValue in
            if let id = newValue {
                openProject(id: id)
            } else {
                closeProject()
            }
        }
        .onChange(of: selectedChapter) { _, newValue in
            PluginManager.shared.context.updateSelectedChapter(newValue)
        }

    }

    /// 打开指定 ID 的项目数据库。
    private func openProject(id: UUID) {
        guard let meta = ProjectRegistry.shared.project(withID: id) else {
            selectedProjectID = nil
            return
        }
        
        // 释放旧容器
        closeProject()

        let schema = Schema([
            Project.self,
            Volume.self,
            Chapter.self,
            StoryScene.self,
            Character.self,
            WorldSetting.self,
            OutlineNode.self,
            Note.self,
            ContentBlockRef.self,
            SpreadsheetSheet.self,
            SpreadsheetCell.self,
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
                PluginManager.shared.context.updateProject(project, container: container)
            } else {
                // 数据库中不存在 Project 记录（异常情况），新建一个
                // 使用注册表中的 UUID，避免数据库与注册表 ID 不一致
                let newProject = Project(
                    title: meta.title,
                    author: meta.author,
                    summary: meta.summary,
                    storagePath: meta.storagePath,
                    targetWordCount: meta.targetWordCount,
                    dailyWordGoal: meta.dailyWordGoal
                )
                newProject.id = meta.id
                context.insert(newProject)
                try context.save()
                self.projectContainer = container
                self.currentProject = newProject
                PluginManager.shared.context.updateProject(newProject, container: container)
            }
        } catch {
            print("打开项目失败: \(error)")
            selectedProjectID = nil
        }
    }

    /// 关闭当前项目，清理数据库容器，并将最新统计信息同步到注册表。
    private func closeProject() {
        syncProjectStats()
        PluginManager.shared.context.updateProject(nil, container: nil)
        PluginManager.shared.context.updateSelectedChapter(nil)
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

    /// 主编辑界面：左侧 NavigationSplitView + 右侧 .inspector 检查器面板。
    @ViewBuilder
    private func mainInterface(project: Project) -> some View {
        NavigationSplitView {
            ChapterTreeView(
                project: project,
                selectedChapter: $selectedChapter
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 280)
        } detail: {
            Group {
                if isSpreadsheetActive {
                    SpreadsheetView(project: project)
                } else if let chapter = selectedChapter {
                    EditorView(
                        project: project,
                        chapter: chapter
                    )
                    .id(chapter.id)
                } else {
                    EmptyEditorView(project: project)
                }
            }
            .inspector(isPresented: $isRightSidebarVisible) {
                rightSidebar(project: project)
                    .inspectorColumnWidth(min: 200, ideal: 280)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    withAnimation {
                        selectedProjectID = nil
                        selectedChapter = nil
                    }
                } label: {
                    Image(systemName: "books.vertical")
                }
                .help("返回项目列表")

                Button {
                    withAnimation {
                        isSpreadsheetActive.toggle()
                    }
                } label: {
                    Image(systemName: isSpreadsheetActive ? "doc.text" : "tablecells")
                }
                .help(isSpreadsheetActive ? "返回编辑器" : "电子表格")
            }

            ToolbarItem {
                Button {
                    isFocusMode = true
                } label: {
                    Image(systemName: "lightbulb")
                }
                .help("专注模式 (⇧⌘F)")
                .disabled(selectedChapter == nil || isSpreadsheetActive)
            }

            ToolbarItem {
                Button {
                    isShowingExport = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("导出")
            }

            #if os(iOS)
                ToolbarItem {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                    .help("设置")
                }
            #endif

            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation {
                        isRightSidebarVisible.toggle()
                    }
                } label: {
                    Image(
                        systemName: isRightSidebarVisible
                            ? "sidebar.right" : "arrow.backward.to.line")
                }
                .help(isRightSidebarVisible ? "隐藏边栏" : "显示边栏")
            }
        }
    }

    /// 右侧辅助面板内容。
    @ViewBuilder
    private func rightSidebar(project: Project) -> some View {
        VStack(spacing: 0) {
            // 顶部分段选择器
            let pluginPanels = PluginManager.shared.allSidebarPanels
            if pluginPanels.isEmpty {
                Picker("", selection: $rightSidebarTab) {
                    ForEach(RightPanelTab.allCases, id: \.self) { tab in
                        Image(systemName: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
            } else {
                // 当存在插件面板时，使用 Menu 或扩展的 picker
                pluginTabPicker(pluginPanels: pluginPanels)
                    .padding()
            }

            Divider()

            // 面板内容
            if let panelID = selectedPluginPanelID,
               let panel = pluginPanels.first(where: { $0.id == panelID }) {
                panel.content()
            } else {
                switch rightSidebarTab {
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
    }
    
    /// 扩展的标签选择器，同时支持原生面板和插件面板。
    @ViewBuilder
    private func pluginTabPicker(pluginPanels: [PluginSidebarPanel]) -> some View {
        HStack(spacing: 4) {
            ForEach(RightPanelTab.allCases, id: \.self) { tab in
                Button {
                    selectedPluginPanelID = nil
                    rightSidebarTab = tab
                } label: {
                    Image(systemName: tab.icon)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(selectedPluginPanelID == nil && rightSidebarTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                        .foregroundStyle(selectedPluginPanelID == nil && rightSidebarTab == tab ? .primary : .secondary)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            if !pluginPanels.isEmpty {
                Divider().frame(height: 20)
                
                ForEach(pluginPanels) { panel in
                    Button {
                        selectedPluginPanelID = panel.id
                    } label: {
                        Image(systemName: panel.icon)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(selectedPluginPanelID == panel.id ? Color.accentColor.opacity(0.15) : Color.clear)
                            .foregroundStyle(selectedPluginPanelID == panel.id ? .primary : .secondary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help(panel.title)
                }
            }
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

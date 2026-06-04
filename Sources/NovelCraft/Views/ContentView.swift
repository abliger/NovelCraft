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
    /// 当前选中的卷
    @State private var selectedVolume: Volume? = nil
    /// 当前展开的卷 ID 集合
    @State private var expandedVolumeIDs: Set<UUID> = []
    /// 是否正在恢复项目状态（恢复期间跳过保存）
    @State private var isRestoringState = false
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
            saveProjectState()
        }
        .onChange(of: selectedVolume) { _, _ in
            saveProjectState()
        }

    }

    /// 打开指定 ID 的项目数据库。
    private func openProject(id: UUID) {
        guard let meta = ProjectRegistry.shared.project(withID: id) else {
            selectedProjectID = nil
            return
        }
        
        // 笔记项目不需要右侧边栏
        if meta.projectType == "note" {
            isRightSidebarVisible = false
        }
        
        // 释放旧容器
        closeProject()

        let schema = AppSchema.shared

        let dbURL = URL(fileURLWithPath: meta.storagePath)
            .appendingPathComponent("NovelCraft.store")
        let config = ModelConfiguration(schema: schema, url: dbURL)

        do {
            let container = try ModelContainer(for: schema, configurations: config)
            try setupProject(from: container, meta: meta)
        } catch {
            print("打开项目失败，尝试重建数据库: \(error)")
            // Schema 不兼容时删除旧数据库并重建
            do {
                if FileManager.default.fileExists(atPath: dbURL.path) {
                    try FileManager.default.removeItem(at: dbURL)
                }
                let container = try ModelContainer(for: schema, configurations: config)
                try setupProject(from: container, meta: meta)
            } catch {
                print("重建数据库失败: \(error)")
                selectedProjectID = nil
            }
        }
    }
    
    /// 从已打开的容器加载或创建 Project 记录。
    private func setupProject(from container: ModelContainer, meta: ProjectMeta) throws {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Project>()
        let dbProjects = try context.fetch(descriptor)

        let project: Project
        if let existing = dbProjects.first {
            // 同步注册表中的最新元数据到数据库
            syncMetaToProject(meta: meta, project: existing, context: context)
            project = existing
        } else {
            // 数据库中不存在 Project 记录，新建一个
            let newProject = Project(
                title: meta.title,
                author: meta.author,
                summary: meta.summary,
                storagePath: meta.storagePath,
                targetWordCount: meta.targetWordCount,
                dailyWordGoal: meta.dailyWordGoal,
                projectType: meta.projectType,
                linkedProjectID: meta.linkedProjectID
            )
            newProject.id = meta.id
            context.insert(newProject)
            try context.save()
            project = newProject
        }
        
        self.projectContainer = container
        self.currentProject = project
        PluginManager.shared.context.updateProject(project, container: container)
        loadProjectState(project: project, context: context)
    }

    /// 关闭当前项目，清理数据库容器，并将最新统计信息同步到注册表。
    private func closeProject() {
        saveProjectState()
        syncProjectStats()
        PluginManager.shared.context.updateProject(nil, container: nil)
        PluginManager.shared.context.updateSelectedChapter(nil)
        projectContainer = nil
        currentProject = nil
        selectedChapter = nil
        selectedVolume = nil
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
        project.projectType = meta.projectType
        project.linkedProjectID = meta.linkedProjectID
        try? context.save()
    }
    
    // MARK: - 项目状态持久化
    
    private func projectStateKey(for projectID: UUID) -> String {
        "NovelCraft.projectState.\(projectID.uuidString)"
    }
    
    /// 保存当前项目的选中项到 UserDefaults。
    private func saveProjectState() {
        guard let project = currentProject else { return }
        var state: [String: Any] = [:]
        if let chapter = selectedChapter {
            state["selectedChapterID"] = chapter.id.uuidString
        }
        if let volume = selectedVolume {
            state["selectedVolumeID"] = volume.id.uuidString
        }
        if let data = try? JSONSerialization.data(withJSONObject: state) {
            UserDefaults.standard.set(data, forKey: projectStateKey(for: project.id))
        }
    }
    
    /// 从 UserDefaults 恢复项目的选中项与展开状态。
    private func loadProjectState(project: Project, context: ModelContext) {
        guard let data = UserDefaults.standard.data(forKey: projectStateKey(for: project.id)),
              let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        if let chapterIDString = state["selectedChapterID"] as? String,
           let chapterID = UUID(uuidString: chapterIDString) {
            selectedChapter = project.volumes
                .flatMap { $0.chapters }
                .first { $0.id == chapterID }
        }
        
        if let volumeIDString = state["selectedVolumeID"] as? String,
           let volumeID = UUID(uuidString: volumeIDString) {
            selectedVolume = project.volumes.first { $0.id == volumeID }
        }
        
        if let expandedIDs = state["expandedVolumeIDs"] as? [String] {
            expandedVolumeIDs = Set(expandedIDs.compactMap { UUID(uuidString: $0) })
        }
    }

    /// 主编辑界面：左侧 NavigationSplitView + 右侧条件渲染的辅助面板。
    /// 注意：macOS 上 .inspector 在 resize 时存在 AppKit 布局崩溃的已知问题，
    /// 因此改用 HStack 条件渲染实现右侧边栏。
    @ViewBuilder
    private func mainInterface(project: Project) -> some View {
        NavigationSplitView {
            ChapterTreeView(
                project: project,
                selectedChapter: $selectedChapter,
                selectedVolume: $selectedVolume,
                expandedVolumes: $expandedVolumeIDs
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 280)
        } detail: {

            HStack(spacing: 0) {
                Group {
                    if isSpreadsheetActive {
                        SpreadsheetView(project: project)
                    } else if let chapter = selectedChapter {
                        EditorView(
                            project: project,
                            chapter: chapter
                        )
                        .id(chapter.id)
                    } else if let volume = selectedVolume {
                        if project.projectType == "note" {
                            VolumeNoteEditorView(project: project, volume: volume)
                                .id(volume.id)
                        } else {
                            VolumeOutlineEditorView(project: project, volume: volume)
                                .id(volume.id)
                        }
                    } else {
                        EmptyEditorView(project: project)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isRightSidebarVisible {
                    HStack(spacing: 0) {
                        Divider()
                        rightSidebar(project: project)
                            .frame(minWidth: 200, idealWidth: 280, maxWidth: 400)
                    }
                    .transition(.move(edge: .trailing))
                }
            }
            .animation(.default, value: isRightSidebarVisible)
        }
        .id("split_\(project.id)")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    withAnimation {
                        selectedProjectID = nil
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
                
                let hasLinkedProject = currentProject.map {
                    ProjectRegistry.shared.findLinkedProjectID(for: $0.id) != nil
                } ?? false
                Button {
                    if let project = currentProject,
                       let linkedID = ProjectRegistry.shared.findLinkedProjectID(for: project.id) {
                        selectedProjectID = linkedID
                        isSpreadsheetActive = false
                    }
                } label: {
                    Image(systemName: "arrow.left.arrow.right.circle")
                        .opacity(hasLinkedProject ? 1.0 : 0.3)
                }
                .disabled(!hasLinkedProject)
                .help(hasLinkedProject ? "跳转到联动项目" : "未设置联动项目")
            }

            ToolbarItem {
                Button {
                    isFocusMode = true
                } label: {
                    Image(systemName: "lightbulb")
                }
                .help("专注模式 (⇧⌘F)")
                .disabled(selectedChapter == nil || selectedVolume != nil || isSpreadsheetActive)
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

            if currentProject?.projectType != "note" {
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
    }

    /// 右侧辅助面板内容。
    @ViewBuilder
    private func rightSidebar(project: Project) -> some View {
        VStack(spacing: 0) {
            // 顶部分段选择器
            // 注意：macOS 上 .segmented Picker 底层为 NSSegmentedControl，
            // 在面板宽度变化时极易触发 AppKit 布局断言崩溃，因此统一使用纯 SwiftUI 按钮组。
            let pluginPanels = PluginManager.shared.allSidebarPanels
            if pluginPanels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(RightPanelTab.allCases, id: \.self) { tab in
                        Button {
                            selectedPluginPanelID = nil
                            rightSidebarTab = tab
                        } label: {
                            Image(systemName: tab.icon)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(rightSidebarTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                                .foregroundStyle(rightSidebarTab == tab ? .primary : .secondary)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            } else {
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
        if project?.projectType == "note" {
            Color.clear
        } else {
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

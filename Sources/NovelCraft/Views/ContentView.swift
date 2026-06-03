import SwiftData
import SwiftUI

/// 应用主界面视图，负责管理项目选择、侧边栏导航、编辑器展示与全局工具栏。
struct ContentView: View {
    /// 当前选中的项目 ID（nil 表示处于项目列表）
    @State private var selectedProjectID: UUID? = nil
    /// 当前项目的数据库容器
    @State private var projectContainer: ModelContainer?
    /// 当前项目的数据库实例
    @State private var currentProject: Project?

    /// 是否显示电子表格
    @State private var isSpreadsheetActive: Bool = false
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

        let schema = AppSchema.shared

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

    /// 主编辑界面：左侧 NavigationSplitView + 编辑器详情区。
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

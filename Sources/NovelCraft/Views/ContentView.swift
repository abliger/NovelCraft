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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor<Project>(\.updatedAt, order: .reverse)]) private var projects: [Project]
    
    /// 当前选中的项目（使用 ID 避免引用失效）
    @State private var selectedProjectID: UUID? = nil
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
    
    /// 根据 ID 重新获取项目实例（防止引用失效或对象被删除）
    private var selectedProject: Project? {
        guard let id = selectedProjectID else { return nil }
        return projects.first { $0.id == id }
    }
    
    var body: some View {
        Group {
            if isFocusMode, let project = selectedProject, let chapter = selectedChapter {
                FocusModeView(
                    project: project,
                    chapter: chapter,
                    isFocusMode: $isFocusMode
                )
            } else if selectedProject == nil {
                ProjectListView(selectedProjectID: $selectedProjectID)
            } else {
                mainInterface
            }
        }
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 600)
        #endif
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $isShowingExport) {
            if let project = selectedProject {
                ExportView(project: project, chapter: selectedChapter)
            }
        }
    }
    
    /// 主编辑界面，包含侧边栏与详情区的 NavigationSplitView。
    @ViewBuilder
    private var mainInterface: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
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
            
            ToolbarItem {
                if let project = selectedProject {
                    Text(project.title)
                        .font(.headline)
                }
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
    private var sidebar: some View {
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
                    project: selectedProject,
                    selectedChapter: $selectedChapter
                )
            case .characters:
                CharacterListView(project: selectedProject)
            case .world:
                WorldSettingListView(project: selectedProject)
            case .outline:
                OutlineView(project: selectedProject)
            case .notes:
                NoteListView(project: selectedProject)
            }
        }
    }
    
    /// 详情区视图，根据是否选中章节展示编辑器或空状态。
    @ViewBuilder
    private var detailView: some View {
        if let chapter = selectedChapter, let project = selectedProject {
            EditorView(
                project: project,
                chapter: chapter
            )
        } else {
            EmptyEditorView(project: selectedProject)
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

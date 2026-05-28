import SwiftUI
import SwiftData

enum SidebarTab: String, CaseIterable {
    case chapters = "章节"
    case characters = "角色"
    case world = "世界观"
    case outline = "大纲"
    case notes = "便签"
    
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

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor<Project>(\.updatedAt, order: .reverse)]) private var projects: [Project]
    
    @State private var selectedProject: Project? = nil
    @State private var selectedTab: SidebarTab = .chapters
    @State private var selectedChapter: Chapter? = nil
    @State private var isShowingProjectList = true
    @State private var isFocusMode = false
    @State private var isShowingSettings = false
    @State private var isShowingExport = false
    @State private var searchText = ""
    
    var body: some View {
        Group {
            if isFocusMode, let project = selectedProject, let chapter = selectedChapter {
                FocusModeView(
                    project: project,
                    chapter: chapter,
                    isFocusMode: $isFocusMode
                )
            } else if selectedProject == nil {
                ProjectListView(selectedProject: $selectedProject)
            } else {
                mainInterface
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }
    
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
                        selectedProject = nil
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
    
    @ViewBuilder
    private var detailView: some View {
        if let chapter = selectedChapter {
            EditorView(
                project: selectedProject!,
                chapter: chapter
            )
        } else {
            EmptyEditorView(project: selectedProject)
        }
    }
}

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

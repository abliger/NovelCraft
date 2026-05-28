import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor<Project>(\.updatedAt, order: .reverse)]) private var projects: [Project]
    
    @Binding var selectedProject: Project?
    @State private var isShowingNewProject = false
    @State private var searchText = ""
    @State private var projectToDelete: Project? = nil
    
    private var filteredProjects: [Project] {
        if searchText.isEmpty { return projects }
        return projects.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.author.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 20)], spacing: 20) {
                    ForEach(filteredProjects) { project in
                        ProjectCard(project: project, selectedProject: $selectedProject)
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $isShowingNewProject) {
            NewProjectView { project in
                selectedProject = project
            }
        }
        .alert("确认删除", isPresented: Binding(
            get: { projectToDelete != nil },
            set: { if !$0 { projectToDelete = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let project = projectToDelete {
                    modelContext.delete(project)
                    try? modelContext.save()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除项目将同时删除所有关联的章节、角色等数据，此操作不可撤销。")
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("我的小说")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("\(projects.count) 个项目")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                SearchField(text: $searchText)
                    .frame(width: 250)
                
                Button {
                    isShowingNewProject = true
                } label: {
                    Label("新建项目", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

struct ProjectCard: View {
    let project: Project
    @Binding var selectedProject: Project?
    
    var body: some View {
        Button {
            selectedProject = project
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 80)
                        .overlay(
                            Image(systemName: "book.closed")
                                .font(.title2)
                                .foregroundStyle(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.title)
                            .font(.headline)
                            .lineLimit(2)
                        
                        if !project.author.isEmpty {
                            Text(project.author)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                if !project.summary.isEmpty {
                    Text(project.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                
                Divider()
                
                HStack {
                    Label("\(project.totalWordCount) 字", systemImage: "textformat")
                        .font(.caption2)
                    
                    Spacer()
                    
                    ProgressView(value: project.progressPercentage)
                        .frame(width: 60)
                    
                    Text("\(Int(project.progressPercentage * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct NewProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var author = ""
    @State private var summary = ""
    @State private var targetWordCount = 50000
    @State private var dailyWordGoal = 2000
    
    let onCreate: (Project) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("新建项目")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("取消") { dismiss() }
            }
            .padding()
            
            Divider()
            
            Form {
                Section("基本信息") {
                    TextField("小说名称", text: $title)
                    TextField("作者", text: $author)
                    TextEditor(text: $summary)
                        .frame(height: 80)
                }
                
                Section("写作目标") {
                    Stepper("目标字数: \(targetWordCount)", value: $targetWordCount, step: 5000)
                    Stepper("每日目标: \(dailyWordGoal)", value: $dailyWordGoal, step: 500)
                }
            }
            .formStyle(.grouped)
            .padding()
            
            Spacer()
            
            HStack {
                Spacer()
                Button("创建") {
                    let project = Project(
                        title: title.isEmpty ? "未命名小说" : title,
                        author: author,
                        summary: summary,
                        targetWordCount: targetWordCount,
                        dailyWordGoal: dailyWordGoal
                    )
                    
                    let volume = Volume(title: "第一卷", order: 0)
                    volume.project = project
                    
                    let chapter = Chapter(title: "第一章", order: 0)
                    chapter.volume = volume
                    
                    modelContext.insert(project)
                    modelContext.insert(volume)
                    modelContext.insert(chapter)
                    try? modelContext.save()
                    
                    onCreate(project)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
            }
            .padding()
        }
        .frame(width: 450, height: 400)
    }
}

struct SearchField: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索项目...", text: $text)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(.tertiarySystemFill))
        .cornerRadius(8)
    }
}

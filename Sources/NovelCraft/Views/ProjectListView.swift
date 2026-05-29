import SwiftUI
import SwiftData

/// 项目列表视图，以卡片网格形式展示所有小说项目，支持搜索与新建。
struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor<Project>(\.updatedAt, order: .reverse)]) private var projects: [Project]
    
    @Binding var selectedProjectID: UUID?
    @State private var isShowingNewProject = false
    @State private var searchText = ""
    @State private var projectToDelete: Project? = nil
    
    /// 根据搜索文本过滤后的项目列表
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
                        ProjectCard(project: project, selectedProjectID: $selectedProjectID)
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
        .sheet(isPresented: $isShowingNewProject) {
            NewProjectView { project in
                selectedProjectID = project.id
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
    
    /// 顶部标题栏，包含项目计数、搜索框与新建按钮。
    private var header: some View {
        HStack(spacing: 16) {
            Text("项目")
                .font(.title2)
                .fontWeight(.bold)
            
            SearchField(text: $searchText)
                .frame(maxWidth: 300)
            
            Spacer()
            
            Button {
                isShowingNewProject = true
            } label: {
                Label("新建项目", systemImage: "plus")
                    .fontWeight(.medium)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(6)
        }
        .padding()
    }
}

/// 项目卡片视图，展示单个项目的标题、作者、进度与统计信息。
struct ProjectCard: View {
    let project: Project
    @Binding var selectedProjectID: UUID?
    
    var body: some View {
        Button {
            selectedProjectID = project.id
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(project.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let data = project.coverImageData, let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                
                Text(project.author.isEmpty ? "未填写作者" : project.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Text(project.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                Spacer()
                
                HStack {
                    Text("\(project.totalWordCount) 字")
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
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(.secondarySystemBackground))
            #endif
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

/// 新建项目弹窗，收集小说名称、作者、简介、封面、存储位置与写作目标。
struct NewProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var author = ""
    @State private var summary = ""
    @State private var coverImageData: Data? = nil
    @State private var storagePath: String? = nil
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
            
            ScrollView {
                Form {
                    #if os(macOS)
                    Section("封面") {
                        HStack(spacing: 12) {
                            if let coverImageData, let nsImage = NSImage(data: coverImageData) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundStyle(.secondary)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Button("选择封面") {
                                    selectImageFile { data in
                                        if let data { coverImageData = data }
                                    }
                                }
                                if coverImageData != nil {
                                    Button("清除封面") {
                                        coverImageData = nil
                                    }
                                    .foregroundColor(.red)
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    #endif
                    
                    Section("基本信息") {
                        TextField("小说名称", text: $title)
                        TextField("作者", text: $author)
                        TextEditor(text: $summary)
                            .frame(height: 60)
                    }
                    
                    #if os(macOS)
                    Section("存储位置") {
                        HStack {
                            Text(storagePath ?? "使用默认位置")
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(storagePath == nil ? .secondary : .primary)
                            Spacer()
                            HStack(spacing: 8) {
                                Button(storagePath == nil ? "选择位置" : "更改") {
                                    selectStorageDirectory { path in
                                        if let path { storagePath = path }
                                    }
                                }
                                if storagePath != nil {
                                    Button("恢复默认") {
                                        storagePath = nil
                                    }
                                    .foregroundColor(.red)
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    #endif
                    
                    Section("写作目标") {
                        Stepper("目标字数: \(targetWordCount)", value: $targetWordCount, step: 5000)
                        Stepper("每日目标: \(dailyWordGoal)", value: $dailyWordGoal, step: 500)
                    }
                }
                .formStyle(.grouped)
                .padding()
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("创建") {
                    let project = Project(
                        title: title.isEmpty ? "未命名小说" : title,
                        author: author,
                        summary: summary,
                        coverImageData: coverImageData,
                        storagePath: storagePath,
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
        .frame(minWidth: 450, idealWidth: 450, minHeight: 400, idealHeight: 520)
    }
}

#if os(macOS)
import AppKit

/// 打开文件选择器选择图片文件
func selectImageFile(completion: @escaping (Data?) -> Void) {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowedContentTypes = [.image]
    if panel.runModal() == .OK, let url = panel.url {
        completion(try? Data(contentsOf: url))
    } else {
        completion(nil)
    }
}

/// 打开文件夹选择器选择存储目录
func selectStorageDirectory(completion: @escaping (String?) -> Void) {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.prompt = "选择"
    if panel.runModal() == .OK, let url = panel.url {
        completion(url.path)
    } else {
        completion(nil)
    }
}
#endif

/// 通用搜索输入框，带清除按钮。
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

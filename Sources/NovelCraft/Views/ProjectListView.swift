import SwiftUI
import SwiftData
#if os(iOS)
import PhotosUI
#endif

/// 项目列表视图，以卡片网格形式展示所有小说项目，支持搜索与新建。
struct ProjectListView: View {
    @Binding var selectedProjectID: UUID?
    
    @State private var projects: [ProjectMeta] = []
    @State private var isShowingNewProject = false
    @State private var searchText = ""
    @State private var projectToDelete: ProjectMeta? = nil
    @State private var projectToEdit: ProjectMeta? = nil

    /// 根据搜索文本过滤后的项目列表
    private var filteredProjects: [ProjectMeta] {
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
                        ProjectCard(
                            project: project,
                            selectedProjectID: $selectedProjectID,
                            onInfo: { projectToEdit = project },
                            onDelete: { projectToDelete = project }
                        )
                    }
                }
                .padding()
            }
        }
        .onAppear(perform: loadProjects)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
        .sheet(isPresented: $isShowingNewProject) {
            NewProjectView { meta in
                loadProjects()
                selectedProjectID = meta.id
            }
        }
        .sheet(item: $projectToEdit) { meta in
            ProjectInfoView(meta: meta, onSaved: loadProjects)
        }
        .alert("确认删除", isPresented: Binding(
            get: { projectToDelete != nil },
            set: { if !$0 { projectToDelete = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let meta = projectToDelete {
                    deleteProject(meta)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除项目将同时删除所有关联的章节、角色等数据及项目文件夹，此操作不可撤销。")
        }
    }
    
    private func loadProjects() {
        projects = ProjectRegistry.shared.loadProjects()
    }
    
    private func deleteProject(_ meta: ProjectMeta) {
        do {
            try FileManager.default.removeItem(atPath: meta.storagePath)
            ProjectRegistry.shared.deleteProject(id: meta.id)
        } catch {
            print("删除项目文件夹失败: \(error)")
        }
        loadProjects()
    }
    
    /// 顶部标题栏，包含项目计数、搜索框与新建按钮。
    private var header: some View {
        HStack(spacing: 16) {
            Text("项目")
                .font(.title2)
                .fontWeight(.bold)
            
            SearchField(text: $searchText, placeholder: "搜索项目...")
                .frame(maxWidth: 300)
            
            Spacer()
            
            Button {
                NotificationCenter.default.post(name: .showPluginManager, object: nil)
            } label: {
                Image(systemName: "puzzlepiece.extension")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("插件管理")
            
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
    let project: ProjectMeta
    @Binding var selectedProjectID: UUID?
    var onInfo: () -> Void
    var onDelete: () -> Void
    
    @State private var coverImageData: Data? = nil
    
    var body: some View {
        Button {
            selectedProjectID = project.id
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(project.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if project.projectType == "note" {
                        Text("笔记")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    if let coverImageData {
                        CoverImagePreview(coverImageData: coverImageData)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                
                if project.projectType != "note" {
                    Text(project.author.isEmpty ? "未填写作者" : project.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Text(project.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                Spacer()
                
                if project.projectType != "note" {
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
        .contextMenu {
            Button("项目信息") {
                onInfo()
            }
            Divider()
            Button("删除项目", role: .destructive) {
                onDelete()
            }
        }
        .task(id: project.id) {
            await loadCover()
        }
    }
    
    private func loadCover() async {
        let coverPath = (project.storagePath as NSString).appendingPathComponent("cover.png")
        guard FileManager.default.fileExists(atPath: coverPath) else { return }
        // 在后台线程读取封面文件，避免阻塞主线程
        let data = await Task.detached {
            try? Data(contentsOf: URL(fileURLWithPath: coverPath))
        }.value
        coverImageData = data
    }
}

/// 项目信息视图，用于查看和编辑已有项目的基本信息、封面、存储位置与写作目标。
struct ProjectInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    let meta: ProjectMeta
    let onSaved: () -> Void
    
    @State private var title = ""
    @State private var author = ""
    @State private var summary = ""
    @State private var coverImageData: Data? = nil
    @State private var targetWordCount = 50000
    @State private var dailyWordGoal = 2000
    @State private var linkedProjectID: UUID? = nil
    @State private var allNovelProjects: [ProjectMeta] = []
    #if os(iOS)
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    #endif
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("项目信息")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("取消") { dismiss() }
            }
            .padding()
            
            Divider()
            
            ScrollView {
                Form {
                    Section("封面") {
                        HStack(spacing: 12) {
                            CoverImagePreview(coverImageData: coverImageData)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            VStack(alignment: .leading, spacing: 6) {
                                #if os(macOS)
                                Button("选择封面") {
                                    selectImageFile { data in
                                        if let data { coverImageData = data }
                                    }
                                }
                                #else
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Text("选择封面")
                                }
                                .onChange(of: selectedPhotoItem) { _, newItem in
                                    Task {
                                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                            coverImageData = data
                                        }
                                    }
                                }
                                #endif
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
                    
                    Section("基本信息") {
                        TextField("小说名称", text: $title)
                        if meta.projectType != "note" {
                            TextField("作者", text: $author)
                        }
                        TextEditor(text: $summary)
                            .frame(height: 60)
                    }
                    
                    Section("存储位置") {
                        HStack {
                            Text(meta.storagePath)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    
                    if meta.projectType != "note" {
                        Section("写作目标") {
                            Stepper("目标字数: \(targetWordCount)", value: $targetWordCount, step: 5000)
                            Stepper("每日目标: \(dailyWordGoal)", value: $dailyWordGoal, step: 500)
                        }
                    }
                    
                    if meta.projectType == "note" {
                        Section("联动设置") {
                            Picker("联动小说项目", selection: $linkedProjectID) {
                                Text("不联动").tag(UUID?.none)
                                ForEach(allNovelProjects) { project in
                                    Text(project.title).tag(Optional(project.id))
                                }
                            }
                        }
                    } else if let linkedNote = allNovelProjects.first(where: { $0.linkedProjectID == meta.id }) {
                        // 小说项目被笔记项目联动时，只读显示
                        Section("联动设置") {
                            HStack {
                                Text("被笔记项目联动")
                                Spacer()
                                Text(linkedNote.title)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .padding()
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("保存") {
                    saveProject()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 450, idealWidth: 450, minHeight: 400, idealHeight: 520)
        .onAppear {
            title = meta.title
            author = meta.author
            summary = meta.summary
            targetWordCount = meta.targetWordCount
            dailyWordGoal = meta.dailyWordGoal
            linkedProjectID = meta.linkedProjectID
            allNovelProjects = ProjectRegistry.shared.loadProjects().filter { $0.projectType == "novel" }
            loadCoverData()
        }
    }
    
    
    private func loadCoverData() {
        let coverPath = (meta.storagePath as NSString).appendingPathComponent("cover.png")
        if FileManager.default.fileExists(atPath: coverPath) {
            coverImageData = try? Data(contentsOf: URL(fileURLWithPath: coverPath))
        }
    }
    
    private func saveProject() {
        guard !title.isEmpty else { return }
        
        var updatedMeta = meta
        updatedMeta.title = title
        updatedMeta.author = author
        updatedMeta.summary = summary
        updatedMeta.targetWordCount = targetWordCount
        updatedMeta.dailyWordGoal = dailyWordGoal
        updatedMeta.updatedAt = Date()
        updatedMeta.linkedProjectID = linkedProjectID
        
        let coverPath = (meta.storagePath as NSString).appendingPathComponent("cover.png")
        if let coverData = coverImageData {
            try? coverData.write(to: URL(fileURLWithPath: coverPath))
        } else {
            try? FileManager.default.removeItem(atPath: coverPath)
        }
        
        // 同步更新项目数据库中的 Project 实体
        do {
            let dbURL = URL(fileURLWithPath: meta.storagePath).appendingPathComponent("NovelCraft.store")
            let container = try ProjectDatabase.openOrCreate(at: dbURL)
            let context = container.mainContext
            
            let descriptor = FetchDescriptor<Project>()
            let dbProjects = try context.fetch(descriptor)
            if let project = dbProjects.first {
                project.title = title
                project.author = author
                project.summary = summary
                project.targetWordCount = targetWordCount
                project.dailyWordGoal = dailyWordGoal
                project.linkedProjectID = linkedProjectID
                project.updatedAt = Date()
                try context.save()
            }
        } catch {
            print("更新项目数据库失败: \(error)")
        }
        
        ProjectRegistry.shared.updateProject(updatedMeta)
        onSaved()
        dismiss()
    }
}

struct NewProjectView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var author = ""
    @State private var summary = ""
    @State private var coverImageData: Data? = nil
    @State private var baseStoragePath: String? = nil
    @State private var targetWordCount = 50000
    @State private var dailyWordGoal = 2000
    @State private var projectType = ProjectType.novel
    @State private var linkedProjectID: UUID? = nil
    @State private var allNovelProjects: [ProjectMeta] = []
    #if os(iOS)
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    #endif
    @State private var showPathExistsAlert = false
    
    let onCreate: (ProjectMeta) -> Void
    
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
                    Section("封面") {
                        HStack(spacing: 12) {
                            CoverImagePreview(coverImageData: coverImageData)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            VStack(alignment: .leading, spacing: 6) {
                                #if os(macOS)
                                Button("选择封面") {
                                    selectImageFile { data in
                                        if let data { coverImageData = data }
                                    }
                                }
                                #else
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Text("选择封面")
                                }
                                .onChange(of: selectedPhotoItem) { _, newItem in
                                    Task {
                                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                            coverImageData = data
                                        }
                                    }
                                }
                                #endif
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
                    
                    Section("基本信息") {
                        Picker("项目类型", selection: $projectType) {
                            ForEach(ProjectType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: projectType) { _, newValue in
                            if newValue == .novel {
                                linkedProjectID = nil
                            }
                        }
                        
                        if projectType == .note {
                            Picker("联动小说项目", selection: $linkedProjectID) {
                                Text("不联动").tag(UUID?.none)
                                ForEach(allNovelProjects) { meta in
                                    Text(meta.title).tag(Optional(meta.id))
                                }
                            }
                        }
                        
                        TextField(projectType == .novel ? "小说名称" : "笔记名称", text: $title)
                        if projectType == .novel {
                            TextField("作者", text: $author)
                        }
                        TextEditor(text: $summary)
                            .frame(height: 60)
                    }
                    
                    #if os(macOS)
                    Section("存储位置") {
                        HStack {
                            Text(baseStoragePath ?? defaultStoragePath())
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.secondary)
                            Spacer()
                            HStack(spacing: 8) {
                                Button(baseStoragePath == nil ? "选择位置" : "更改") {
                                    selectStorageDirectory { path in
                                        if let path { baseStoragePath = path }
                                    }
                                }
                                if baseStoragePath != nil {
                                    Button("恢复默认") {
                                        baseStoragePath = nil
                                    }
                                    .foregroundColor(.red)
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    #endif
                    
                    if projectType == .novel {
                        Section("写作目标") {
                            Stepper("目标字数: \(targetWordCount)", value: $targetWordCount, step: 5000)
                            Stepper("每日目标: \(dailyWordGoal)", value: $dailyWordGoal, step: 500)
                        }
                    }
                }
                .formStyle(.grouped)
                .padding()
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("创建") {
                    createProject()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 450, idealWidth: 450, minHeight: 400, idealHeight: 520)
        .onAppear {
            allNovelProjects = ProjectRegistry.shared.loadProjects().filter { $0.projectType == "novel" }
        }
        .alert("项目已存在", isPresented: $showPathExistsAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("该路径下已存在同名项目，请更换名称或存储位置。")
        }
    }
    
    private func createProject() {
        guard !title.isEmpty else { return }
        
        let sanitizedTitle = sanitizeFileName(title)
        let basePath = baseStoragePath ?? defaultStoragePath()
        let projectPath = (basePath as NSString).appendingPathComponent(sanitizedTitle)
        
        guard !FileManager.default.fileExists(atPath: projectPath) else {
            showPathExistsAlert = true
            return
        }
        
        do {
            try FileManager.default.createDirectory(atPath: projectPath, withIntermediateDirectories: true)
            
            let coverPath = (projectPath as NSString).appendingPathComponent("cover.png")
            if let coverData = coverImageData {
                try coverData.write(to: URL(fileURLWithPath: coverPath))
            }
            
            let dbURL = URL(fileURLWithPath: projectPath).appendingPathComponent("NovelCraft.store")
            let container = try ProjectDatabase.openOrCreate(at: dbURL)
            let context = container.mainContext
            
            let project = Project(
                title: title,
                author: author,
                summary: summary,
                storagePath: projectPath,
                targetWordCount: targetWordCount,
                dailyWordGoal: dailyWordGoal,
                projectType: projectType.rawValue,
                linkedProjectID: linkedProjectID
            )
            context.insert(project)
            
            if projectType == .novel {
                let volume = Volume(title: "第一卷", order: 0)
                volume.project = project
                context.insert(volume)
                
                let chapter = Chapter(title: "第一章", order: 0)
                chapter.volume = volume
                context.insert(chapter)
            }
            
            try context.save()
            
            let meta = ProjectMeta(
                id: project.id,
                title: title,
                author: author,
                summary: summary,
                storagePath: projectPath,
                createdAt: project.createdAt,
                updatedAt: project.updatedAt,
                targetWordCount: targetWordCount,
                dailyWordGoal: dailyWordGoal,
                totalWordCount: 0,
                progressPercentage: 0,
                projectType: projectType.rawValue,
                linkedProjectID: linkedProjectID
            )
            ProjectRegistry.shared.addProject(meta)
            
            onCreate(meta)
            dismiss()
        } catch {
            print("创建项目失败: \(error)")
        }
    }
    
    private func defaultStoragePath() -> String {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let path = documents.appendingPathComponent("NovelCraftProjects", isDirectory: true).path
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }
}

/// 跨平台封面图片预览组件
private struct CoverImagePreview: View {
    let coverImageData: Data?
    
    var body: some View {
        if let coverImageData {
            #if os(macOS)
            if let nsImage = NSImage(data: coverImageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
            #else
            if let uiImage = UIImage(data: coverImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
            #endif
        } else {
            placeholder
        }
    }
    
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.secondary.opacity(0.15))
            .overlay(
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            )
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



import Foundation

/// 项目类型枚举。
enum ProjectType: String, Codable, CaseIterable {
    case novel = "novel"
    case note = "note"

    var displayName: String {
        switch self {
        case .novel: return "小说项目"
        case .note: return "笔记项目"
        }
    }
}

/// 项目元数据，存储在项目注册表中，用于项目列表展示与快速索引。
struct ProjectMeta: Codable, Identifiable {
    let id: UUID
    var title: String
    var author: String
    var summary: String
    var storagePath: String
    var createdAt: Date
    var updatedAt: Date
    var targetWordCount: Int
    var dailyWordGoal: Int
    var totalWordCount: Int
    var progressPercentage: Double
    /// 项目类型：novel（小说项目）或 note（笔记项目）
    var projectType: String
    /// 联动项目 ID（笔记项目可关联到小说项目）
    var linkedProjectID: UUID?

    enum CodingKeys: String, CodingKey {
        case id, title, author, summary, storagePath
        case createdAt, updatedAt
        case targetWordCount, dailyWordGoal
        case totalWordCount, progressPercentage
        case projectType, linkedProjectID
    }

    init(
        id: UUID,
        title: String,
        author: String = "",
        summary: String = "",
        storagePath: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        targetWordCount: Int = 50000,
        dailyWordGoal: Int = 2000,
        totalWordCount: Int = 0,
        progressPercentage: Double = 0,
        projectType: String = "novel",
        linkedProjectID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.summary = summary
        self.storagePath = storagePath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.targetWordCount = targetWordCount
        self.dailyWordGoal = dailyWordGoal
        self.totalWordCount = totalWordCount
        self.progressPercentage = progressPercentage
        self.projectType = projectType
        self.linkedProjectID = linkedProjectID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        summary = try container.decode(String.self, forKey: .summary)
        storagePath = try container.decode(String.self, forKey: .storagePath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        targetWordCount = try container.decode(Int.self, forKey: .targetWordCount)
        dailyWordGoal = try container.decode(Int.self, forKey: .dailyWordGoal)
        totalWordCount = try container.decode(Int.self, forKey: .totalWordCount)
        progressPercentage = try container.decode(Double.self, forKey: .progressPercentage)
        projectType = try container.decodeIfPresent(String.self, forKey: .projectType) ?? "novel"
        linkedProjectID = try container.decodeIfPresent(UUID.self, forKey: .linkedProjectID)
    }
}

/// 项目注册表，管理应用支持目录下的 `projects.json`，负责项目元数据的持久化。
/// 每个项目的实际内容（卷、章节等）存储在项目自己的 SwiftData 数据库中。
class ProjectRegistry {
    static let shared = ProjectRegistry()

    private let lock = NSRecursiveLock()
    /// 内存缓存，减少频繁磁盘 I/O
    private var cachedProjects: [ProjectMeta]?
    private let registryURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NovelCraft", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.registryURL = dir.appendingPathComponent("projects.json")
    }

    func loadProjects() -> [ProjectMeta] {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cachedProjects { return cached }
        do {
            let data = try Data(contentsOf: registryURL)
            let projects = try JSONDecoder().decode([ProjectMeta].self, from: data)
            cachedProjects = projects
            return projects
        } catch {
            print("加载项目注册表失败: \(error)")
            return []
        }
    }

    func saveProjects(_ projects: [ProjectMeta]) {
        lock.lock()
        defer { lock.unlock() }
        do {
            let data = try JSONEncoder().encode(projects)
            let tempURL = registryURL.deletingLastPathComponent()
                .appendingPathComponent("projects_" + UUID().uuidString + ".tmp")
            try data.write(to: tempURL)
            // 使用 replaceItemAt 实现原子替换，避免 remove + move 中间出现 crash 导致数据丢失
            let _ = try FileManager.default.replaceItemAt(registryURL, withItemAt: tempURL)
            cachedProjects = projects
        } catch {
            print("保存项目注册表失败: \(error)")
        }
    }

    func addProject(_ project: ProjectMeta) {
        lock.lock()
        defer { lock.unlock() }
        var projects = cachedProjects ?? _loadProjectsWithoutLock()
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
        _saveProjectsWithoutLock(projects)
    }

    func updateProject(_ project: ProjectMeta) {
        lock.lock()
        defer { lock.unlock() }
        var projects = cachedProjects ?? _loadProjectsWithoutLock()
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            _saveProjectsWithoutLock(projects)
        }
    }

    func deleteProject(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        var projects = cachedProjects ?? _loadProjectsWithoutLock()
        projects.removeAll { $0.id == id }
        _saveProjectsWithoutLock(projects)
    }

    func project(withID id: UUID) -> ProjectMeta? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cachedProjects { return cached.first { $0.id == id } }
        return _loadProjectsWithoutLock().first { $0.id == id }
    }

    /// 查找与指定项目双向联动的项目 ID。
    /// - 若当前项目是笔记项目，返回其 linkedProjectID（联动的小说项目）。
    /// - 若当前项目是小说项目，返回 linked 到它的小说项目 ID（笔记项目）。
    func findLinkedProjectID(for projectID: UUID) -> UUID? {
        lock.lock()
        defer { lock.unlock() }
        let all = cachedProjects ?? _loadProjectsWithoutLock()
        guard let meta = all.first(where: { $0.id == projectID }) else { return nil }
        if meta.projectType == "note" {
            return meta.linkedProjectID
        }
        // 小说项目：查找哪个笔记项目 linked 到了当前项目
        return all.first(where: { $0.projectType == "note" && $0.linkedProjectID == projectID })?.id
    }

    /// 强制刷新缓存，使下次读取重新从磁盘加载
    func invalidateCache() {
        lock.lock()
        defer { lock.unlock() }
        cachedProjects = nil
    }

    // MARK: - 内部方法（调用方必须已持有锁）

    private func _loadProjectsWithoutLock() -> [ProjectMeta] {
        do {
            let data = try Data(contentsOf: registryURL)
            let projects = try JSONDecoder().decode([ProjectMeta].self, from: data)
            cachedProjects = projects
            return projects
        } catch {
            print("加载项目注册表失败: \(error)")
            return []
        }
    }

    private func _saveProjectsWithoutLock(_ projects: [ProjectMeta]) {
        do {
            let data = try JSONEncoder().encode(projects)
            let tempURL = registryURL.deletingLastPathComponent()
                .appendingPathComponent("projects_" + UUID().uuidString + ".tmp")
            try data.write(to: tempURL)
            let _ = try FileManager.default.replaceItemAt(registryURL, withItemAt: tempURL)
            cachedProjects = projects
        } catch {
            print("保存项目注册表失败: \(error)")
        }
    }
}



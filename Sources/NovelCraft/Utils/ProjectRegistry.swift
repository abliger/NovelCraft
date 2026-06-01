import Foundation

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



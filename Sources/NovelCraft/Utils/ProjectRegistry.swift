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

    private var registryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NovelCraft", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("projects.json")
    }

    func loadProjects() -> [ProjectMeta] {
        guard let data = try? Data(contentsOf: registryURL) else { return [] }
        return (try? JSONDecoder().decode([ProjectMeta].self, from: data)) ?? []
    }

    func saveProjects(_ projects: [ProjectMeta]) {
        if let data = try? JSONEncoder().encode(projects) {
            try? data.write(to: registryURL)
        }
    }

    func addProject(_ project: ProjectMeta) {
        var projects = loadProjects()
        projects.append(project)
        saveProjects(projects)
    }

    func updateProject(_ project: ProjectMeta) {
        var projects = loadProjects()
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            saveProjects(projects)
        }
    }

    func deleteProject(id: UUID) {
        var projects = loadProjects()
        projects.removeAll { $0.id == id }
        saveProjects(projects)
    }

    func project(withID id: UUID) -> ProjectMeta? {
        return loadProjects().first { $0.id == id }
    }
}

/// 清理文件名中的非法字符，防止路径遍历和无效文件名。
func sanitizeFileName(_ name: String) -> String {
    var result = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|.")
    result = result.components(separatedBy: invalidChars).joined(separator: "-")
    result = result.replacingOccurrences(of: "..", with: "-")
    if result.hasPrefix("-") {
        result = "_" + result
    }
    if result.isEmpty {
        result = "未命名"
    }
    return result
}

import Foundation
import SwiftData

/// 项目数据库管理器，负责安全地打开、迁移和备份项目 SwiftData 数据库。
///
/// 核心原则：无论遇到任何错误，绝不删除用户已有的数据库文件。
/// 当 Schema 不兼容或数据库损坏时，旧数据库会被完整备份到同目录下的
/// `NovelCraft.store.backup.<时间戳>` 文件夹中，然后创建新的空数据库。
enum ProjectDatabase {

    /// 安全地打开或创建指定路径的项目数据库。
    ///
    /// 1. 首先尝试正常打开现有数据库（SwiftData 会自动处理轻量级迁移）。
    /// 2. 如果打开失败，将旧数据库文件完整备份，然后创建新的空数据库。
    /// 3. 如果创建仍然失败，则抛出错误。
    ///
    /// - Parameter dbURL: 数据库文件 URL（通常为 `.../项目目录/NovelCraft.store`）
    /// - Returns: 配置好的 `ModelContainer`
    static func openOrCreate(at dbURL: URL) throws -> ModelContainer {
        let schema = AppSchema.shared
        let config = ModelConfiguration(schema: schema, url: dbURL)

        // 如果数据库文件已存在，尝试正常打开（SwiftData 会自动处理轻量级迁移）
        if FileManager.default.fileExists(atPath: dbURL.path) {
            do {
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                print("数据库打开失败，尝试备份后重建: \(error.localizedDescription)")
                backupDatabaseIfExists(at: dbURL)
                return try ModelContainer(for: schema, configurations: config)
            }
        } else {
            return try ModelContainer(for: schema, configurations: config)
        }
    }

    /// 备份指定路径的数据库文件及其相关辅助文件（如 WAL、SHM）。
    private static func backupDatabaseIfExists(at dbURL: URL) {
        let fm = FileManager.default
        let directory = dbURL.deletingLastPathComponent()
        let baseName = dbURL.lastPathComponent

        guard fm.fileExists(atPath: dbURL.path) else { return }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withFullDate,
            .withTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
        ]
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupDir = directory.appendingPathComponent("\(baseName).backup.\(timestamp)")

        do {
            try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)

            guard let files = try? fm.contentsOfDirectory(atPath: directory.path) else { return }

            for file in files {
                // 匹配所有以数据库名为前缀的文件（包括 .store、.store-wal、.store-shm 等）
                if file.hasPrefix(baseName) {
                    let source = directory.appendingPathComponent(file)
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: source.path, isDirectory: &isDir), !isDir.boolValue {
                        let destination = backupDir.appendingPathComponent(file)
                        try fm.moveItem(at: source, to: destination)
                    }
                }
            }

            print("数据库已备份至: \(backupDir.path)")
        } catch {
            print("数据库备份失败: \(error.localizedDescription)")
        }
    }
}

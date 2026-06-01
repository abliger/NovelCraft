import Foundation

/// 文件同步引擎，负责将章节内容按 `storagePath/卷名/章名.md` 结构写入文件系统。
struct FileSyncEngine {
    /// 将指定章节的内容同步到项目指定的存储目录。
    /// 路径结构为：storagePath/卷名/章名.md
    static func syncChapterToDisk(_ chapter: Chapter, project: Project) {
        let storagePath = project.storagePath
        
        // 验证路径安全性：禁止路径中包含 .. 组件，并拒绝相对路径
        let url = URL(fileURLWithPath: storagePath)
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL.path
        // 检查路径中是否存在 .. 组件（resolvingSymlinksInPath 不会规范化 ..）
        let pathComponents = resolved.split(separator: "/")
        if pathComponents.contains("..") || resolved.contains("/../") || resolved.hasSuffix("/..") || resolved == ".." {
            print("文件同步失败: 路径包含非法组件 \(storagePath)")
            return
        }
        // 进一步验证：解析后的路径必须是绝对路径
        if !resolved.hasPrefix("/") {
            print("文件同步失败: 路径必须是绝对路径 \(storagePath)")
            return
        }
        
        guard let volume = chapter.volume else { return }
        
        let sanitizedVolume = sanitizeFileName(volume.title)
        // 章节文件名加入 UUID 前缀以避免同名冲突
        let sanitizedChapter = sanitizeFileName(chapter.title)
        let fileName = "\(sanitizedChapter)_\(chapter.id.uuidString.prefix(8)).md"
        
        let baseURL = URL(fileURLWithPath: storagePath)
        let volumeURL = baseURL.appendingPathComponent(sanitizedVolume)
        let fileURL = volumeURL.appendingPathComponent(fileName)
        
        do {
            try FileManager.default.createDirectory(
                at: volumeURL,
                withIntermediateDirectories: true
            )
            try chapter.content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("文件同步失败: \(error)")
        }
    }
}

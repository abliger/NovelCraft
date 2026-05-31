import Foundation

/// 文件同步引擎，负责将章节内容按 `storagePath/卷名/章名.md` 结构写入文件系统。
struct FileSyncEngine {
    /// 将指定章节的内容同步到项目指定的存储目录。
    /// 路径结构为：storagePath/卷名/章名.md
    static func syncChapterToDisk(_ chapter: Chapter, project: Project) {
        let storagePath = project.storagePath
        
        // 验证路径安全性：禁止路径中包含 .. 组件
        let url = URL(fileURLWithPath: storagePath)
        let standardized = url.standardizedFileURL.path
        if standardized != url.path, url.pathComponents.contains("..") {
            print("文件同步失败: 路径包含非法组件 \(storagePath)")
            return
        }
        
        guard let volume = chapter.volume else { return }
        
        let sanitizedVolume = sanitizeFileName(volume.title)
        let sanitizedChapter = sanitizeFileName(chapter.title)
        
        let baseURL = URL(fileURLWithPath: storagePath)
        let volumeURL = baseURL.appendingPathComponent(sanitizedVolume)
        let fileURL = volumeURL.appendingPathComponent("\(sanitizedChapter).md")
        
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

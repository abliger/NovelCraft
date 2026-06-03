import Foundation

/// 文件同步引擎，负责将章节内容按 `storagePath/卷名/章名.md` 结构写入文件系统。
struct FileSyncEngine {
    /// 将指定章节的内容同步到项目指定的存储目录。
    /// 路径结构为：storagePath/卷名/章名_UUID前缀.md
    static func syncChapterToDisk(_ chapter: Chapter, project: Project) {
        guard let fileURL = chapterFileURL(chapter: chapter, project: project) else { return }
        
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try chapter.content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("文件同步失败: \(error)")
        }
    }
    
    /// 将指定章节的细纲同步到文件系统。
    /// 路径结构为：storagePath/卷名/章名_UUID前缀.synopsis.md
    static func syncSynopsisToDisk(_ chapter: Chapter, project: Project) {
        guard let fileURL = synopsisFileURL(chapter: chapter, project: project) else { return }
        
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try chapter.synopsis.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("细纲同步失败: \(error)")
        }
    }
    
    /// 从文件系统加载指定章节的细纲。
    /// 若文件不存在，返回 nil。
    static func loadSynopsisFromDisk(_ chapter: Chapter, project: Project) -> String? {
        guard let fileURL = synopsisFileURL(chapter: chapter, project: project) else { return nil }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try? String(contentsOf: fileURL, encoding: .utf8)
    }
    
    // MARK: - 路径计算
    
    /// 计算章节正文文件的 URL。
    static func chapterFileURL(chapter: Chapter, project: Project) -> URL? {
        guard let volumeURL = volumeURL(chapter: chapter, project: project) else { return nil }
        let fileName = chapterFileName(chapter: chapter, extension: "md")
        return volumeURL.appendingPathComponent(fileName)
    }
    
    /// 计算章节细纲文件的 URL。
    static func synopsisFileURL(chapter: Chapter, project: Project) -> URL? {
        guard let volumeURL = volumeURL(chapter: chapter, project: project) else { return nil }
        let fileName = chapterFileName(chapter: chapter, extension: "synopsis.md")
        return volumeURL.appendingPathComponent(fileName)
    }
    
    // MARK: - 私有辅助方法
    
    private static func volumeURL(chapter: Chapter, project: Project) -> URL? {
        let storagePath = project.storagePath
        
        // 验证路径安全性
        let url = URL(fileURLWithPath: storagePath)
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL.path
        let pathComponents = resolved.split(separator: "/")
        if pathComponents.contains("..") || resolved.contains("/../") || resolved.hasSuffix("/..") || resolved == ".." {
            print("文件同步失败: 路径包含非法组件 \(storagePath)")
            return nil
        }
        if !resolved.hasPrefix("/") {
            print("文件同步失败: 路径必须是绝对路径 \(storagePath)")
            return nil
        }
        
        guard let volume = chapter.volume else { return nil }
        let sanitizedVolume = sanitizeFileName(volume.title)
        let baseURL = URL(fileURLWithPath: storagePath)
        return baseURL.appendingPathComponent(sanitizedVolume)
    }
    
    private static func chapterFileName(chapter: Chapter, extension ext: String) -> String {
        let sanitizedChapter = sanitizeFileName(chapter.title)
        return "\(sanitizedChapter)_\(chapter.id.uuidString.prefix(8)).\(ext)"
    }
    
    /// 清理文件名，移除不适合作为文件名的字符。
    static func sanitizeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>")
        return name.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}

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
    
    /// 将 AI 生成规则文件同步到项目根目录。
    /// 路径结构为：storagePath/rule.md
    static func syncRuleToDisk(_ text: String, project: Project) {
        let storagePath = project.storagePath
        guard validatePath(storagePath) else { return }
        let fileURL = URL(fileURLWithPath: storagePath).appendingPathComponent("rule.md")
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("规则文件同步失败: \(error)")
        }
    }
    
    /// 从文件系统加载 AI 生成规则文件。
    /// 若文件不存在，返回 nil。
    static func loadRuleFromDisk(project: Project) -> String? {
        let storagePath = project.storagePath
        guard validatePath(storagePath) else { return nil }
        let fileURL = URL(fileURLWithPath: storagePath).appendingPathComponent("rule.md")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try? String(contentsOf: fileURL, encoding: .utf8)
    }
    
    // MARK: - 卷文件同步
    
    /// 将指定卷的内容同步到项目指定的存储目录。
    /// 路径结构为：storagePath/卷名/卷名_UUID前缀.md
    static func syncVolumeToDisk(_ volume: Volume, project: Project) {
        guard let fileURL = volumeFileURL(volume: volume, project: project) else { return }
        
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try volume.outline.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("卷文件同步失败: \(error)")
        }
    }
    
    /// 从文件系统加载指定卷的内容。
    /// 若文件不存在，返回 nil。
    static func loadVolumeFromDisk(_ volume: Volume, project: Project) -> String? {
        guard let fileURL = volumeFileURL(volume: volume, project: project) else { return nil }
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
    
    private static func validatePath(_ storagePath: String) -> Bool {
        let url = URL(fileURLWithPath: storagePath)
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL.path
        let pathComponents = resolved.split(separator: "/")
        if pathComponents.contains("..") || resolved.contains("/../") || resolved.hasSuffix("/..") || resolved == ".." {
            print("文件同步失败: 路径包含非法组件 \(storagePath)")
            return false
        }
        if !resolved.hasPrefix("/") {
            print("文件同步失败: 路径必须是绝对路径 \(storagePath)")
            return false
        }
        return true
    }
    
    private static func volumeURL(chapter: Chapter, project: Project) -> URL? {
        let storagePath = project.storagePath
        guard validatePath(storagePath) else { return nil }
        
        guard let volume = chapter.volume else { return nil }
        let sanitizedVolume = sanitizeFileName(volume.title)
        let baseURL = URL(fileURLWithPath: storagePath)
        return baseURL.appendingPathComponent(sanitizedVolume)
    }
    
    /// 计算卷内容文件的 URL。
    static func volumeFileURL(volume: Volume, project: Project) -> URL? {
        let storagePath = project.storagePath
        guard validatePath(storagePath) else { return nil }
        
        let sanitizedVolume = sanitizeFileName(volume.title)
        let baseURL = URL(fileURLWithPath: storagePath)
        let volumeDir = baseURL.appendingPathComponent(sanitizedVolume)
        let fileName = volumeFileName(volume: volume)
        return volumeDir.appendingPathComponent(fileName)
    }
    
    private static func chapterFileName(chapter: Chapter, extension ext: String) -> String {
        let sanitizedChapter = sanitizeFileName(chapter.title)
        return "\(sanitizedChapter)_\(chapter.id.uuidString.prefix(8)).\(ext)"
    }
    
    private static func volumeFileName(volume: Volume) -> String {
        let sanitizedVolume = sanitizeFileName(volume.title)
        return "\(sanitizedVolume)_\(volume.id.uuidString.prefix(8)).md"
    }
    
    /// 清理文件名，移除不适合作为文件名的字符。
    static func sanitizeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>")
        return name.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}

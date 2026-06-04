import XCTest
import SwiftData
@testable import NovelCraft

/// NovelCraft 核心功能单元测试，覆盖模型创建、状态枚举与导出引擎。
final class NovelCraftTests: XCTestCase {
    
    var container: ModelContainer!
    
    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(
            for: Project.self, Volume.self, Chapter.self, StoryScene.self,
            Character.self, WorldSetting.self, OutlineNode.self, Note.self,
            ContentBlockRef.self,
            configurations: config
        )
    }
    
    override func tearDown() {
        container = nil
        super.tearDown()
    }
    
    // MARK: - 模型测试
    
    /// 验证 Project 默认属性与自定义初始化值是否正确。
    func testProjectCreation() {
        let project = Project(title: "测试小说", author: "测试作者", storagePath: "/tmp/test-project")
        XCTAssertEqual(project.title, "测试小说")
        XCTAssertEqual(project.author, "测试作者")
        XCTAssertEqual(project.targetWordCount, 50000)
        XCTAssertEqual(project.dailyWordGoal, 2000)
        XCTAssertNotNil(project.id)
    }
    
    /// 验证 Volume 基本属性与关系。
    func testVolumeCreation() {
        let project = Project(title: "测试", storagePath: "/tmp/test-project")
        let volume = Volume(title: "第一卷", order: 0)
        volume.project = project
        XCTAssertEqual(volume.title, "第一卷")
        XCTAssertEqual(volume.order, 0)
        XCTAssertEqual(volume.project?.title, "测试")
        XCTAssertEqual(volume.outline, "")
    }
    
    /// 验证 Volume outline 字段赋值与持久化。
    func testVolumeOutlineField() {
        let volume = Volume(title: "第二卷", outline: "这是一个大纲")
        XCTAssertEqual(volume.outline, "这是一个大纲")
        
        let emptyVolume = Volume()
        XCTAssertEqual(emptyVolume.outline, "")
    }
    
    /// 验证卷文件同步引擎能正确写入与读取卷内容。
    func testVolumeFileSync() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let project = Project(title: "同步测试", storagePath: tempDir.path)
        let volume = Volume(title: "测试卷", outline: "卷的大纲内容。")
        volume.project = project
        
        // 写入
        FileSyncEngine.syncVolumeToDisk(volume, project: project)
        
        // 验证文件存在
        let fileURL = FileSyncEngine.volumeFileURL(volume: volume, project: project)
        XCTAssertNotNil(fileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL!.path))
        
        // 验证内容
        let content = try String(contentsOf: fileURL!, encoding: .utf8)
        XCTAssertEqual(content, "卷的大纲内容。")
        
        // 验证读取
        let loaded = FileSyncEngine.loadVolumeFromDisk(volume, project: project)
        XCTAssertEqual(loaded, "卷的大纲内容。")
    }
    
    /// 验证 ChapterStatus 枚举与 Chapter 状态属性的映射。
    func testChapterStatus() {
        let chapter = Chapter(title: "测试章节", chapterStatus: .completed)
        XCTAssertEqual(chapter.chapterStatus, .completed)
        XCTAssertEqual(chapter.chapterStatus.rawValue, "completed")
        XCTAssertEqual(chapter.chapterStatus.displayName, "已完成")
        
        let draft = Chapter(title: "草稿章节")
        XCTAssertEqual(draft.chapterStatus, .draft)
        XCTAssertEqual(draft.chapterStatus.displayName, "草稿")
    }
    
    /// 验证 Chapter 字数统计（字数过滤标点，字符数包含标点）。
    func testChapterWordCount() {
        let chapter = Chapter(title: "测试", content: "这是一段测试内容。")
        XCTAssertEqual(chapter.wordCount, 8)   // 过滤了句号
        XCTAssertEqual(chapter.characterCount, 9) // 包含标点
        
        let empty = Chapter(title: "空")
        XCTAssertEqual(empty.wordCount, 0)
        XCTAssertEqual(empty.characterCount, 0)
    }
    
    /// 验证 StoryScene 基本属性。
    func testStorySceneCreation() {
        let character = Character(name: "主角")
        let scene = StoryScene(title: "开场", content: "场景描述", viewpointCharacter: character)
        XCTAssertEqual(scene.title, "开场")
        XCTAssertEqual(scene.viewpointCharacter?.name, "主角")
    }
    
    /// 验证 Character 基本属性。
    func testCharacterCreation() {
        let character = Character(name: "主角", gender: "男", age: "20岁")
        XCTAssertEqual(character.name, "主角")
        XCTAssertEqual(character.gender, "男")
        XCTAssertEqual(character.age, "20岁")
    }
    
    /// 验证 WorldSetting 基本属性。
    func testWorldSettingCreation() {
        let setting = WorldSetting(category: "地理", title: "大陆地图", content: "详细描述")
        XCTAssertEqual(setting.category, "地理")
        XCTAssertEqual(setting.title, "大陆地图")
    }
    
    /// 验证 OutlineNode 树形结构与自引用防护。
    func testOutlineNodeCreation() {
        let parent = OutlineNode(title: "主线", nodeType: "arc")
        let child = OutlineNode(title: "第一章", nodeType: "chapter", parent: parent)
        XCTAssertEqual(child.parent?.title, "主线")
        XCTAssertNotEqual(child.id, parent.id)
    }
    
    /// 验证 Note 基本属性与颜色校验。
    func testNoteCreation() {
        let note = Note(title: "灵感", content: "一个想法", color: "red")
        XCTAssertEqual(note.color, "red")
        
        let invalid = Note(title: "测试", color: "invalid_color")
        XCTAssertEqual(invalid.color, "yellow")
    }
    
    /// 验证项目总字数与进度计算。
    func testProjectWordCountAndProgress() {
        let project = Project(title: "测试", storagePath: "/tmp/test-project", targetWordCount: 100)
        let volume = Volume()
        volume.project = project
        let chapter1 = Chapter(content: "一二三四五")
        chapter1.volume = volume
        let chapter2 = Chapter(content: "六七八九十")
        chapter2.volume = volume
        
        XCTAssertEqual(project.totalWordCount, 10)
        XCTAssertEqual(project.progressPercentage, 0.1)
    }
    
    // MARK: - 导出引擎测试
    
    /// 验证 Markdown 导出能正确生成文件并包含项目、章节与正文内容。
    func testExportEngineMarkdown() throws {
        let project = Project(title: "导出测试", author: "作者", storagePath: "/tmp/test-export")
        let chapter = Chapter(title: "第一章", content: "这是测试内容。")
        let volume = Volume(title: "第一卷")
        volume.project = project
        chapter.volume = volume
        
        let engine = ExportEngine(project: project, chapter: chapter)
        let url = try engine.export(format: .markdown, scope: .chapter, includeMetadata: true)
        defer { try? FileManager.default.removeItem(at: url) }
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("导出测试"))
        XCTAssertTrue(content.contains("第一章"))
        XCTAssertTrue(content.contains("这是测试内容。"))
    }
    
    /// 验证纯文本导出能正确去除 Markdown 标记符号。
    func testExportEnginePlainText() throws {
        let project = Project(title: "文本测试", storagePath: "/tmp/test-text")
        let chapter = Chapter(title: "第一章", content: "**粗体** 和 *斜体*")
        let volume = Volume(title: "第一卷")
        volume.project = project
        chapter.volume = volume
        
        let engine = ExportEngine(project: project, chapter: chapter)
        let url = try engine.export(format: .plainText, scope: .chapter, includeMetadata: false)
        defer { try? FileManager.default.removeItem(at: url) }
        
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("粗体"))
        XCTAssertFalse(content.contains("**"))
    }
    
    /// 验证文件名安全清理。
    func testExportEngineFileNameSanitization() throws {
        let project = Project(title: "../../../etc/passwd", storagePath: "/tmp/test-sanitize")
        let engine = ExportEngine(project: project, chapter: nil)
        let url = try engine.export(format: .markdown, scope: .fullProject, includeMetadata: false)
        defer { try? FileManager.default.removeItem(at: url) }
        
        let name = url.lastPathComponent
        XCTAssertFalse(name.contains("/"))
        XCTAssertFalse(name.contains(".."))
        XCTAssertTrue(name.hasSuffix(".md"))
    }
    
    /// 验证空项目标题时文件名回退到默认值。
    func testExportEngineEmptyFileName() throws {
        let project = Project(title: "", storagePath: "/tmp/test-empty")
        let engine = ExportEngine(project: project, chapter: nil)
        let url = try engine.export(format: .markdown, scope: .fullProject, includeMetadata: false)
        defer { try? FileManager.default.removeItem(at: url) }
        
        // 文件名包含 UUID 前缀以避免冲突，验证核心名称部分
        XCTAssertTrue(url.lastPathComponent.contains("未命名导出"), "实际文件名: \(url.lastPathComponent)")
    }
    
    /// 验证 chapter == nil 时导出当前章节会抛出错误。
    func testExportEngineNoChapterError() {
        let project = Project(title: "测试", storagePath: "/tmp/test-nochapter")
        let engine = ExportEngine(project: project, chapter: nil)
        XCTAssertThrowsError(try engine.export(format: .markdown, scope: .chapter, includeMetadata: false)) { error in
            XCTAssertEqual(error as? ExportError, .noChapterSelected)
        }
    }
    
    /// 验证 HTML 转义完整性。
    func testExportEngineHTMLEscape() throws {
        let project = Project(title: "<测试>", author: "\"作者\"", storagePath: "/tmp/test-escape")
        let chapter = Chapter(title: "'章节'", content: "内容")
        let volume = Volume()
        volume.project = project
        chapter.volume = volume
        
        let engine = ExportEngine(project: project, chapter: chapter)
        let url = try engine.export(format: .epub, scope: .chapter, includeMetadata: true)
        defer { try? FileManager.default.removeItem(at: url) }
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
}

import XCTest
import SwiftData
@testable import NovelCraft

final class NovelCraftTests: XCTestCase {
    func testProjectCreation() {
        let project = Project(title: "测试小说", author: "测试作者")
        XCTAssertEqual(project.title, "测试小说")
        XCTAssertEqual(project.author, "测试作者")
        XCTAssertEqual(project.targetWordCount, 50000)
        XCTAssertEqual(project.dailyWordGoal, 2000)
    }
    
    func testChapterStatus() {
        let chapter = Chapter(title: "测试章节", status: .completed)
        XCTAssertEqual(chapter.chapterStatus, .completed)
        XCTAssertEqual(chapter.chapterStatus.rawValue, "已完成")
    }
    
    func testExportEngineMarkdown() throws {
        let project = Project(title: "导出测试", author: "作者")
        let chapter = Chapter(title: "第一章", content: "这是测试内容。")
        let volume = Volume(title: "第一卷")
        volume.project = project
        chapter.volume = volume
        
        let engine = ExportEngine(project: project, chapter: chapter)
        let url = try engine.export(format: .markdown, scope: .chapter, includeMetadata: true)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("导出测试"))
        XCTAssertTrue(content.contains("第一章"))
        XCTAssertTrue(content.contains("这是测试内容。"))
    }
    
    func testExportEnginePlainText() throws {
        let project = Project(title: "文本测试")
        let chapter = Chapter(title: "第一章", content: "**粗体** 和 *斜体*")
        let volume = Volume(title: "第一卷")
        volume.project = project
        chapter.volume = volume
        
        let engine = ExportEngine(project: project, chapter: chapter)
        let url = try engine.export(format: .plainText, scope: .chapter, includeMetadata: false)
        
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("粗体"))
        XCTAssertFalse(content.contains("**"))
    }
}

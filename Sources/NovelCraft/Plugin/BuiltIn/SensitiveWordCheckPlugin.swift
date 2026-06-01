import Foundation
import SwiftUI

/// 敏感词检测插件。
///
/// 作为 ContentProcessor，在保存前检测章节内容中的敏感词并做标记。
/// 作为 ChapterActionContributor，在章节上下文菜单提供「检测敏感词」动作。
@MainActor
final class SensitiveWordCheckPlugin: NovelCraftPlugin, ContentProcessor, ChapterActionContributor {
    let id = "com.novelcraft.plugins.sensitiveword"
    let name = "敏感词检测"
    let description = "检测章节内容中的敏感词汇，支持高亮标记与自动替换建议。"
    let version = "1.0.0"
    let author = "NovelCraft 官方"
    var isEnabled: Bool = true
    
    private var context: PluginContext?
    
    /// 内置敏感词列表（示例级，实际使用应支持用户自定义与外部词库导入）。
    private let sensitiveWords: [String] = [
        "暴力", "色情", "赌博", "毒品", "诈骗",
    ]
    
    /// 敏感词替换建议映射。
    private let replacementMap: [String: String] = [
        "暴力": "冲突",
        "色情": "情感描写",
        "赌博": "博弈",
        "毒品": "禁药",
        "诈骗": "欺诈",
    ]
    
    func setup(context: PluginContext) {
        self.context = context
    }
    
    func teardown() {
        context = nil
    }
    
    // MARK: - ContentProcessor
    
    func process(content: String, chapter: Chapter) -> String {
        // 内容处理器模式下：仅检测并打印日志，不修改原始内容。
        let found = scanSensitiveWords(in: content)
        if !found.isEmpty {
            let wordList = found.map { "「\($0.word)」(\($0.count)次)" }.joined(separator: "、")
            print("[敏感词检测] 章节「\(chapter.title)」发现敏感词: \(wordList)")
        }
        return content
    }
    
    // MARK: - ChapterActionContributor
    
    var chapterActions: [PluginChapterAction] {
        [
            PluginChapterAction(
                id: "\(id).check",
                title: "检测敏感词",
                icon: "exclamationmark.triangle"
            ) { [weak self] chapter in
                self?.showSensitiveWordAlert(for: chapter)
            }
        ]
    }
    
    // MARK: - 检测逻辑
    
    /// 扫描文本中的敏感词，返回发现结果。
    func scanSensitiveWords(in text: String) -> [SensitiveWordResult] {
        var results: [String: Int] = [:]
        for word in sensitiveWords {
            var count = 0
            var searchRange = text.startIndex..<text.endIndex
            while let range = text.range(of: word, options: [], range: searchRange) {
                count += 1
                searchRange = range.upperBound..<text.endIndex
            }
            if count > 0 {
                results[word] = count
            }
        }
        return results.map { SensitiveWordResult(word: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    /// 生成带有敏感词高亮标记的文本（用于预览）。
    func highlightedText(_ text: String) -> String {
        var result = text
        for word in sensitiveWords.sorted(by: { $0.count > $1.count }) {
            result = result.replacingOccurrences(of: word, with: "**[\(word)]**")
        }
        return result
    }
    
    /// 生成自动替换后的文本。
    func autoReplace(in text: String) -> String {
        var result = text
        for (word, replacement) in replacementMap {
            result = result.replacingOccurrences(of: word, with: replacement)
        }
        return result
    }
    
    // MARK: - 交互
    
    private func showSensitiveWordAlert(for chapter: Chapter) {
        let found = scanSensitiveWords(in: chapter.content)
        if found.isEmpty {
            showAlert(title: "敏感词检测", message: "章节「\(chapter.title)」未发现敏感词。")
        } else {
            let wordList = found.map { "• \($0.word)：\($0.count) 次" }.joined(separator: "\n")
            showAlert(
                title: "检测到 \(found.count) 个敏感词",
                message: "章节：\(chapter.title)\n\n\(wordList)\n\n建议在导出前进行适当修改。"
            )
        }
    }
    
    private func showAlert(title: String, message: String) {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
        #endif
        // iOS 上通过 NotificationCenter 发送事件，由视图层响应
        NotificationCenter.default.post(
            name: .init("NovelCraftPluginAlert"),
            object: nil,
            userInfo: ["title": title, "message": message]
        )
    }
}

/// 敏感词扫描结果。
struct SensitiveWordResult: Identifiable {
    let id = UUID()
    let word: String
    let count: Int
}

#if canImport(AppKit)
import AppKit
#endif

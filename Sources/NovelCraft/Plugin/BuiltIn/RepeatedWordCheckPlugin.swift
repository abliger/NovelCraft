import Foundation
import SwiftUI

/// 重复词检测插件。
///
/// 作为 ContentProcessor，检测章节中高频重复使用的词汇。
/// 作为 ChapterActionContributor，在章节上下文菜单提供「重复词分析」动作。
@MainActor
final class RepeatedWordCheckPlugin: NovelCraftPlugin, ContentProcessor, ChapterActionContributor {
    let id = "com.novelcraft.plugins.repeatedword"
    let name = "重复词检测"
    let description = "分析章节中高频重复的词汇，帮助作者发现用词单调的问题。"
    let version = "1.0.0"
    let author = "NovelCraft 官方"
    var isEnabled: Bool = true
    
    private var context: PluginContext?
    
    /// 应被忽略的停用词（虚词、常见助词等）。
    private let stopWords: Set<String> = Set([
        "的", "了", "是", "在", "我", "有", "和", "就", "不", "人",
        "都", "一", "一个", "上", "也", "很", "到", "说", "要", "去",
        "你", "会", "着", "没有", "看", "好", "自己", "这", "那", "之",
        "与", "及", "而", "或", "但", "因为", "所以", "如果", "虽然",
        "他", "她", "它", "们", "得", "地", "着", "过", "把", "被",
        "让", "向", "往", "从", "自", "于", "给", "为", "以", "将",
    ])
    
    func setup(context: PluginContext) {
        self.context = context
    }
    
    func teardown() {
        context = nil
    }
    
    // MARK: - ContentProcessor
    
    func process(content: String, chapter: Chapter) -> String {
        let topWords = analyzeTopWords(in: content, limit: 5)
        if !topWords.isEmpty {
            let wordList = topWords.map { "\($0.word)(\($0.count))" }.joined(separator: "、")
            print("[重复词检测] 章节「\(chapter.title)」高频词: \(wordList)")
        }
        return content
    }
    
    // MARK: - ChapterActionContributor
    
    var chapterActions: [PluginChapterAction] {
        [
            PluginChapterAction(
                id: "\(id).analyze",
                title: "分析重复用词",
                icon: "text.magnifyingglass"
            ) { [weak self] chapter in
                self?.showRepeatedWordAnalysis(for: chapter)
            }
        ]
    }
    
    // MARK: - 分析逻辑
    
    /// 分析文本中高频出现的词汇，返回前 N 个结果（排除停用词和单字）。
    func analyzeTopWords(in text: String, limit: Int = 10, minLength: Int = 2) -> [RepeatedWordResult] {
        // 1. 清理文本：去除标点，统一为空格分隔
        var cleaned = text
        let punctuation = CharacterSet.punctuationCharacters
            .union(.symbols)
            .union(.whitespacesAndNewlines)
        cleaned = cleaned.components(separatedBy: punctuation).joined(separator: " ")
        
        // 2. 分词（简化的基于空格和常见分隔的分词）
        var wordCounts: [String: Int] = [:]
        
        // 中文：滑动窗口分词（2-4 字词）
        let chinesePattern = try? NSRegularExpression(pattern: "[\\u4e00-\\u9fa5]+", options: [])
        let nsRange = NSRange(cleaned.startIndex..., in: cleaned)
        if let matches = chinesePattern?.matches(in: cleaned, options: [], range: nsRange) {
            for match in matches {
                guard let range = Range(match.range, in: cleaned) else { continue }
                let chineseText = String(cleaned[range])
                // 提取 2-4 字词组
                let maxLength = min(4, chineseText.count)
                guard maxLength >= minLength else { continue }
                for length in minLength...maxLength {
                    for i in 0...(chineseText.count - length) {
                        let start = chineseText.index(chineseText.startIndex, offsetBy: i)
                        let end = chineseText.index(start, offsetBy: length)
                        let word = String(chineseText[start..<end])
                        if !stopWords.contains(word) {
                            wordCounts[word, default: 0] += 1
                        }
                    }
                }
            }
        }
        
        // 英文单词
        let englishPattern = try? NSRegularExpression(pattern: "[a-zA-Z]{2,}", options: [])
        if let matches = englishPattern?.matches(in: cleaned, options: [], range: nsRange) {
            for match in matches {
                guard let range = Range(match.range, in: cleaned) else { continue }
                let word = String(cleaned[range]).lowercased()
                if !stopWords.contains(word) {
                    wordCounts[word, default: 0] += 1
                }
            }
        }
        
        // 3. 过滤低频词，排序取前 N
        return wordCounts
            .filter { $0.value >= 3 } // 至少出现 3 次
            .map { RepeatedWordResult(word: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }
    
    /// 计算相邻重复（连续重复的同词）。
    func findAdjacentRepeats(in text: String) -> [AdjacentRepeatResult] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: "。.!?！？\n"))
        var results: [AdjacentRepeatResult] = []
        
        for (index, sentence) in sentences.enumerated() {
            let words = sentence.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            for i in 1..<words.count {
                let current = words[i].trimmingCharacters(in: .punctuationCharacters)
                let previous = words[i-1].trimmingCharacters(in: .punctuationCharacters)
                if current == previous && current.count >= 2 && !stopWords.contains(current) {
                    results.append(AdjacentRepeatResult(
                        sentenceIndex: index,
                        word: current,
                        context: "...\(words[max(0, i-2)...min(words.count-1, i+1)].joined(separator: ""))..."
                    ))
                }
            }
        }
        return results
    }
    
    // MARK: - 交互
    
    private func showRepeatedWordAnalysis(for chapter: Chapter) {
        let topWords = analyzeTopWords(in: chapter.content, limit: 10)
        let adjacent = findAdjacentRepeats(in: chapter.content)
        
        var message = "章节：\(chapter.title)\n\n"
        
        if topWords.isEmpty {
            message += "✅ 未发现明显的用词重复问题。\n"
        } else {
            message += "📊 高频词汇 TOP \(topWords.count):\n"
            for (index, result) in topWords.enumerated() {
                message += "\(index + 1). 「\(result.word)」 — \(result.count) 次\n"
            }
        }
        
        if !adjacent.isEmpty {
            message += "\n⚠️ 发现 \(adjacent.count) 处相邻重复:\n"
            for repeatResult in adjacent.prefix(5) {
                message += "• 「\(repeatResult.word)」\n"
            }
        }
        
        showAlert(title: "重复词分析", message: message)
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
        NotificationCenter.default.post(
            name: .init("NovelCraftPluginAlert"),
            object: nil,
            userInfo: ["title": title, "message": message]
        )
    }
}

/// 高频词分析结果。
struct RepeatedWordResult: Identifiable {
    let id = UUID()
    let word: String
    let count: Int
}

/// 相邻重复结果。
struct AdjacentRepeatResult: Identifiable {
    let id = UUID()
    let sentenceIndex: Int
    let word: String
    let context: String
}

#if canImport(AppKit)
import AppKit
#endif

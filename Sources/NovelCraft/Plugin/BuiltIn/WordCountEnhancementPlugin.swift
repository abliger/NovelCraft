import Foundation
import SwiftUI

/// 字数统计增强插件。
///
/// 作为 ContentProcessor，在保存前统计并记录更详细的字数信息。
/// 作为 EditorToolbarContributor，在工具栏提供一个「详细统计」按钮，
/// 点击后弹窗展示当前章节的字符数、中文字数、标点数、段落数等。
@MainActor
final class WordCountEnhancementPlugin: NovelCraftPlugin, ContentProcessor, EditorToolbarContributor {
    let id = "com.novelcraft.plugins.wordcount"
    let name = "字数统计增强"
    let description = "提供更详细的字数统计信息，包括中文字数、标点数、段落数等。"
    let version = "1.0.0"
    let author = "NovelCraft 官方"
    var isEnabled: Bool = true
    
    private var context: PluginContext?
    @Published var showStatsSheet: Bool = false
    @Published var currentStats: DetailedWordStats?
    
    func setup(context: PluginContext) {
        self.context = context
    }
    
    func teardown() {
        context = nil
    }
    
    // MARK: - ContentProcessor
    
    func process(content: String, chapter: Chapter) -> String {
        // 字数统计增强处理器：目前仅做统计，不修改内容。
        // 未来可在此自动插入字数标记或导出专用注释。
        return content
    }
    
    // MARK: - EditorToolbarContributor
    
    var toolbarItems: [PluginToolbarItem] {
        [
            PluginToolbarItem(
                id: "\(id).stats",
                icon: "chart.bar",
                tooltip: "详细字数统计"
            ) { [weak self] in
                self?.showDetailedStats()
            }
        ]
    }
    
    // MARK: - 统计逻辑
    
    private func showDetailedStats() {
        guard let chapter = context?.selectedChapter else { return }
        currentStats = calculateStats(for: chapter.content)
        showStatsSheet = true
    }
    
    func calculateStats(for text: String) -> DetailedWordStats {
        let totalChars = text.count
        let paragraphs = text.split(separator: "\n", omittingEmptySubsequences: false).count
        
        // 中文字符计数
        let chineseChars = countChineseChars(in: text)
        
        // 英文单词计数
        let englishWords = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.range(of: "[a-zA-Z]+", options: .regularExpression) != nil }
            .count
        
        // 标点符号计数
        let punctuationChars = countPunctuation(in: text)
        
        // 数字计数
        let numberChars = text.filter { $0 >= "0" && $0 <= "9" }.count
        
        return DetailedWordStats(
            totalChars: totalChars,
            chineseChars: chineseChars,
            englishWords: englishWords,
            punctuationChars: punctuationChars,
            numberChars: numberChars,
            paragraphs: paragraphs,
            estimatedReadingTimeMinutes: max(1, chineseChars / 300 + englishWords / 150)
        )
    }
    
    private func countChineseChars(in text: String) -> Int {
        var count = 0
        for scalar in text.unicodeScalars {
            if (scalar.value >= 0x4E00 && scalar.value <= 0x9FFF)
                || (scalar.value >= 0x3400 && scalar.value <= 0x4DBF)
                || (scalar.value >= 0x20000 && scalar.value <= 0x2A6DF)
                || (scalar.value >= 0x2A700 && scalar.value <= 0x2B73F)
                || (scalar.value >= 0x2B740 && scalar.value <= 0x2B81F) {
                count += 1
            }
        }
        return count
    }
    
    private func countPunctuation(in text: String) -> Int {
        let punctuationSet = CharacterSet([
            ",", ".", "!", "?", ";", ":", "\"", "(", ")", "[", "]", "{", "}",
            "·", "、", "。", "，", "！", "？", "；", "：", "（", "）", "【", "】", "《", "》"
        ])
        var count = 0
        for scalar in text.unicodeScalars {
            if punctuationSet.contains(scalar) {
                count += 1
            }
        }
        return count
    }
}

/// 详细字数统计结果。
struct DetailedWordStats: Identifiable {
    let id = UUID()
    let totalChars: Int
    let chineseChars: Int
    let englishWords: Int
    let punctuationChars: Int
    let numberChars: Int
    let paragraphs: Int
    let estimatedReadingTimeMinutes: Int
    
    /// 等效中文字数（中文字符 + 英文单词×2 + 数字）
    var equivalentChineseWords: Int {
        chineseChars + englishWords * 2 + numberChars
    }
}

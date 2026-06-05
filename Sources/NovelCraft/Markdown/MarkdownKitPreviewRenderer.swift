import Foundation
import MarkdownKit

/// 基于 MarkdownKit 的实时预览渲染器，将 Markdown 文本转为 SwiftUI AttributedString。
///
/// 在预览前会预处理 NovelCraft 自定义语法（双向链接、块嵌入），
/// 使其能被标准 Markdown 解析器理解并渲染为可点击链接或占位文本。
enum MarkdownKitPreviewRenderer {

    /// 将 Markdown 文本渲染为 SwiftUI AttributedString。
    static func render(_ markdown: String) -> AttributedString {
        let processed = preprocessCustomSyntax(markdown)

        let parser = MarkdownKit.MarkdownParser()
        let nsAttributedString = parser.parse(processed)

        // 将 NSAttributedString 转为 SwiftUI 可用的 AttributedString
        return AttributedString(nsAttributedString)
    }

    /// 预处理 NovelCraft 自定义语法：
    /// - 双向链接 `((id "锚文本"))` → `[锚文本](novelcraft://block/id)`
    /// - 无锚文本链接 `((id))` → `[引用](novelcraft://block/id)`
    /// - 块嵌入 `{{id}}` → `[嵌入块]`
    private static func preprocessCustomSyntax(_ text: String) -> String {
        var result = text

        // 双向链接（含锚文本）
        let blockRefPattern = #"\(\(([0-9A-Fa-f-]+)\s+"([^"]+)"\)\)"#
        if let regex = try? NSRegularExpression(pattern: blockRefPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: "[$2](novelcraft://block/$1)"
            )
        }

        // 无锚文本的双向链接
        let blockRefSimplePattern = #"\(\(([0-9A-Fa-f-]+)\)\)"#
        if let regex = try? NSRegularExpression(pattern: blockRefSimplePattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: "[引用](novelcraft://block/$1)"
            )
        }

        // 块嵌入
        let blockEmbedPattern = #"\{\{([0-9A-Fa-f-]+)\}\}"#
        if let regex = try? NSRegularExpression(pattern: blockEmbedPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: "[嵌入块]"
            )
        }

        return result
    }
}

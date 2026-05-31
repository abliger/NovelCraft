import Foundation
import SwiftUI

/// Markdown AST 渲染器，将语法树转换为 SwiftUI `AttributedString`
struct MarkdownRenderer {

    static func render(_ node: MDNode) -> AttributedString {
        var renderer = Self()
        return renderer.render(node)
    }

    private func render(_ node: MDNode) -> AttributedString {
        switch node {
        case .document(let children):
            return children.map(render).joined()

        case .heading(let level, let children):
            var result = children.map(render).joined()
            let sizes: [CGFloat] = [28, 24, 20, 18, 16, 14]
            let size = sizes[min(level - 1, 5)]
            result.font = .system(size: size, weight: .bold)
            result.foregroundColor = .primary
            return result + AttributedString("\n\n")

        case .paragraph(let children):
            return children.map(render).joined() + AttributedString("\n\n")

        case .text(let content):
            return AttributedString(content)

        case .bold(let children):
            var result = children.map(render).joined()
            result.font = (result.font ?? .body).bold()
            return result

        case .italic(let children):
            var result = children.map(render).joined()
            result.font = (result.font ?? .body).italic()
            return result

        case .strikethrough(let children):
            var result = children.map(render).joined()
            #if os(macOS)
            result.strikethroughStyle = .single
            #else
            result.strikethroughStyle = .single
            #endif
            return result

        case .codeBlock(_, let content):
            var result = AttributedString(content)
            result.font = .system(.body, design: .monospaced)
            result.backgroundColor = Color.gray.opacity(0.12)
            return result + AttributedString("\n\n")

        case .inlineCode(let content):
            var result = AttributedString(content)
            result.font = .system(.body, design: .monospaced)
            result.backgroundColor = Color.gray.opacity(0.12)
            return result

        case .link(let url, let children):
            var result = children.map(render).joined()
            result.foregroundColor = .accentColor
            #if os(macOS)
            result.underlineStyle = .single
            #else
            result.underlineStyle = .single
            #endif
            return result

        case .blockRef(let id, let anchor):
            let display = anchor?.isEmpty == false ? anchor! : "引用"
            var result = AttributedString(display)
            result.foregroundColor = .purple
            #if os(macOS)
            result.underlineStyle = .single
            #else
            result.underlineStyle = .single
            #endif
            return result

        case .blockEmbed(let id):
            var result = AttributedString("[嵌入块]")
            result.foregroundColor = .blue
            result.backgroundColor = .blue.opacity(0.1)
            #if os(macOS)
            result.underlineStyle = .single
            #else
            result.underlineStyle = .single
            #endif
            return result

        case .image(let alt, let url):
            // 纯文本预览中无法显示图片，用占位符表示
            let isLocal = !url.hasPrefix("http")
            let icon = isLocal ? "🖼️" : "🌐"
            var result = AttributedString("\(icon) [图片: \(alt.isEmpty ? "未命名" : alt)]")
            result.foregroundColor = .secondary
            result.backgroundColor = Color.gray.opacity(0.08)
            result.font = .caption
            return result

        case .orderedList(let items):
            var result = AttributedString("")
            for (index, item) in items.enumerated() {
                var prefix = AttributedString("\(index + 1). ")
                prefix.foregroundColor = .primary
                result += prefix
                result += render(item)
                result += AttributedString("\n")
            }
            return result + AttributedString("\n")

        case .unorderedList(let items):
            var result = AttributedString("")
            for item in items {
                var prefix = AttributedString("• ")
                prefix.foregroundColor = .primary
                result += prefix
                result += render(item)
                result += AttributedString("\n")
            }
            return result + AttributedString("\n")

        case .listItem(let children):
            return children.map(render).joined()

        case .blockQuote(let children):
            var result = AttributedString("┃ ")
            result.foregroundColor = .secondary
            result += children.map(render).joined()
            return result + AttributedString("\n")

        case .horizontalRule:
            var result = AttributedString("────────────────────")
            result.foregroundColor = .secondary
            return result + AttributedString("\n\n")

        case .lineBreak:
            return AttributedString("\n")

        case .softBreak:
            return AttributedString(" ")

        }
    }
}

// MARK: - 辅助扩展

private extension Sequence where Element == AttributedString {
    func joined() -> AttributedString {
        var result = AttributedString("")
        for element in self {
            result += element
        }
        return result
    }
}

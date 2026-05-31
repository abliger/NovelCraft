import Foundation

/// Markdown 与内容块数组之间的双向转换器
enum BlockMarkdownConverter {
    
    /// 将 Markdown 文本解析为 ContentBlock 数组
    static func parse(_ markdown: String) -> [ContentBlock] {
        let ast = MarkdownParser.parse(markdown)
        guard case .document(let children) = ast else {
            return [ContentBlock(type: .paragraph, content: markdown)]
        }
        let blocks = children.compactMap { nodeToBlock($0) }
        return blocks.isEmpty ? [ContentBlock(type: .paragraph, content: markdown)] : blocks
    }
    
    /// 将 ContentBlock 数组序列化为 Markdown 文本
    static func serialize(_ blocks: [ContentBlock]) -> String {
        blocks.map { blockToMarkdown($0) }.joined(separator: "\n\n")
    }
    
    // MARK: - 私有方法
    
    private static func nodeToBlock(_ node: MDNode) -> ContentBlock? {
        switch node {
        case .heading(let level, let children):
            let type: BlockType = {
                switch level {
                case 1: return .heading1
                case 2: return .heading2
                case 3: return .heading3
                case 4: return .heading4
                case 5: return .heading5
                default: return .heading6
                }
            }()
            return ContentBlock(type: type, content: inlineMarkdown(from: children))
            
        case .paragraph(let children):
            return ContentBlock(type: .paragraph, content: inlineMarkdown(from: children))
            
        case .codeBlock(let lang, let content):
            return ContentBlock(type: .code, content: content, language: lang)
            
        case .unorderedList(let items):
            let text = items.map { listItemMarkdown($0) }.joined(separator: "\n")
            return ContentBlock(type: .unorderedList, content: text)
            
        case .orderedList(let items):
            let text = items.map { listItemMarkdown($0) }.joined(separator: "\n")
            return ContentBlock(type: .orderedList, content: text)
            
        case .blockQuote(let children):
            let text = children.map { blockNodeToMarkdown($0) }.joined(separator: "\n")
            return ContentBlock(type: .quote, content: text)
            
        case .horizontalRule:
            return ContentBlock(type: .divider, content: "")
            
        default:
            return nil
        }
    }
    
    /// 将内联节点数组还原为 Markdown 字符串，保留粗体、斜体、链接等格式。
    private static func inlineMarkdown(from nodes: [MDNode]) -> String {
        nodes.map { node in
            switch node {
            case .text(let text):
                return text
            case .bold(let children):
                return "**\(inlineMarkdown(from: children))**"
            case .italic(let children):
                return "*\(inlineMarkdown(from: children))*"
            case .strikethrough(let children):
                return "~~\(inlineMarkdown(from: children))~~"
            case .inlineCode(let content):
                return "`\(content)`"
            case .link(let url, let children):
                return "[\(inlineMarkdown(from: children))](\(url))"
            case .image(let alt, let url):
                return "![\(alt)](\(url))"
            case .blockRef(let id, let anchor):
                if let anchor = anchor {
                    return "((\(id) \"\(anchor)\"))"
                }
                return "((\(id)))"
            case .blockEmbed(let id):
                return "{{\(id)}}"
            default:
                return node.plainText
            }
        }.joined()
    }
    
    /// 将列表项还原为 Markdown 字符串。
    private static func listItemMarkdown(_ node: MDNode) -> String {
        switch node {
        case .listItem(let children):
            // listItem 的 children 通常是 paragraph 节点
            return children.map { child in
                switch child {
                case .paragraph(let inlineChildren):
                    return inlineMarkdown(from: inlineChildren)
                default:
                    return blockNodeToMarkdown(child)
                }
            }.joined(separator: "\n")
        default:
            return node.plainText
        }
    }
    
    /// 将块级节点还原为 Markdown 字符串（用于 blockQuote 等嵌套结构）。
    private static func blockNodeToMarkdown(_ node: MDNode) -> String {
        switch node {
        case .paragraph(let children):
            return inlineMarkdown(from: children)
        case .heading(let level, let children):
            return String(repeating: "#", count: level) + " " + inlineMarkdown(from: children)
        case .codeBlock(let lang, let content):
            let fence = lang.map { "```\($0)\n\(content)\n```" } ?? "```\n\(content)\n```"
            return fence
        case .unorderedList(let items):
            return items.map { "- \($0.plainText)" }.joined(separator: "\n")
        case .orderedList(let items):
            return items.enumerated().map { "\($0.offset + 1). \($0.element.plainText)" }.joined(separator: "\n")
        case .blockQuote(let children):
            return children.map { "> \(blockNodeToMarkdown($0))" }.joined(separator: "\n")
        case .horizontalRule:
            return "---"
        default:
            return node.plainText
        }
    }
    
    private static func blockToMarkdown(_ block: ContentBlock) -> String {
        switch block.type {
        case .paragraph:
            return block.content
        case .heading1:
            return "# \(block.content)"
        case .heading2:
            return "## \(block.content)"
        case .heading3:
            return "### \(block.content)"
        case .heading4:
            return "#### \(block.content)"
        case .heading5:
            return "##### \(block.content)"
        case .heading6:
            return "###### \(block.content)"
        case .unorderedList:
            return block.content
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { "- \($0)" }
                .joined(separator: "\n")
        case .orderedList:
            return block.content
                .split(separator: "\n", omittingEmptySubsequences: false)
                .enumerated()
                .map { "\($0.offset + 1). \($0.element)" }
                .joined(separator: "\n")
        case .quote:
            return block.content
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { "> \($0)" }
                .joined(separator: "\n")
        case .code:
            if let lang = block.language, !lang.isEmpty {
                return "```\(lang)\n\(block.content)\n```"
            }
            return "```\n\(block.content)\n```"
        case .divider:
            return "---"
        }
    }
}

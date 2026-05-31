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
            return ContentBlock(type: type, content: children.map(\.plainText).joined())
            
        case .paragraph(let children):
            return ContentBlock(type: .paragraph, content: children.map(\.plainText).joined())
            
        case .codeBlock(let lang, let content):
            return ContentBlock(type: .code, content: content, language: lang)
            
        case .unorderedList(let items):
            let text = items.map { $0.plainText }.joined(separator: "\n")
            return ContentBlock(type: .unorderedList, content: text)
            
        case .orderedList(let items):
            let text = items.map { $0.plainText }.joined(separator: "\n")
            return ContentBlock(type: .orderedList, content: text)
            
        case .blockQuote(let children):
            return ContentBlock(type: .quote, content: children.map(\.plainText).joined())
            
        case .horizontalRule:
            return ContentBlock(type: .divider, content: "")
            
        default:
            return nil
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

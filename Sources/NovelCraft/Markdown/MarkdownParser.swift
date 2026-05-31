import Foundation

// MARK: - 块级解析器

/// Markdown 块级解析器
///
/// 负责将 Markdown 文本分解为块级结构（标题、段落、列表、代码块等），
/// 并对每个块的内容调用行内解析器处理内联元素。
struct MarkdownBlockParser {
    private var lines: [String]
    private var position: Int = 0

    init(text: String) {
        // 保留空行以正确判断段落边界
        self.lines = text.components(separatedBy: .newlines)
    }

    /// 解析入口，返回文档根节点
    mutating func parse() -> MDNode {
        var blocks: [MDNode] = []
        while !isAtEnd {
            skipEmptyLines()
            guard !isAtEnd else { break }
            if let block = parseBlock() {
                blocks.append(block)
            }
        }
        return .document(children: blocks)
    }

    // MARK: - 私有方法

    private mutating func parseBlock() -> MDNode? {
        let line = currentLine().trimmingCharacters(in: .whitespaces)

        // 围栏代码块 ```
        if line.hasPrefix("```") {
            return parseFencedCodeBlock()
        }

        // 标题 #
        if let heading = parseHeading(line) {
            advance()
            return heading
        }

        // 分隔线 --- / *** / ___
        if isHorizontalRule(line) {
            advance()
            return .horizontalRule
        }

        // 引用块 >
        if line.hasPrefix(">") {
            return parseBlockQuote()
        }

        // 无序列表 - / * / +
        if isUnorderedListItem(line) {
            return parseList(ordered: false)
        }

        // 有序列表 1. / 2. 等
        if isOrderedListItem(line) {
            return parseList(ordered: true)
        }

        // 默认：段落
        return parseParagraph()
    }

    // MARK: 各类块的解析

    private mutating func parseHeading(_ line: String) -> MDNode? {
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        for char in line {
            if char == "#" && level < 6 {
                level += 1
            } else {
                break
            }
        }
        guard level >= 1, level <= 6 else { return nil }
        let rest = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
        var inlineParser = MarkdownInlineParser(text: rest)
        let children = inlineParser.parse()
        return .heading(level: level, children: children)
    }

    private mutating func parseFencedCodeBlock() -> MDNode? {
        let firstLine = currentLine()
        let fence = firstLine.prefix(while: { $0 == "`" })
        let fenceLen = fence.count

        // 语言标识
        var language: String?
        let afterFence = firstLine.dropFirst(fenceLen).trimmingCharacters(in: .whitespaces)
        if !afterFence.isEmpty {
            language = afterFence
        }
        advance()

        var contentLines: [String] = []
        while !isAtEnd {
            let line = currentLine()
            if line.hasPrefix(String(repeating: "`", count: fenceLen)) {
                advance()
                break
            }
            contentLines.append(line)
            advance()
        }

        // 去掉末尾的空行
        while let last = contentLines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            contentLines.removeLast()
        }

        let content = contentLines.joined(separator: "\n")
        return .codeBlock(language: language, content: content)
    }

    private mutating func parseBlockQuote() -> MDNode? {
        var rawLines: [String] = []
        while !isAtEnd {
            let line = currentLine()
            if line.trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let after = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                rawLines.append(String(after))
                advance()
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                // 空行可能表示引用块结束，也可能只是引用块中的空行
                // 向下看一行，如果下一行还是引用，则保留空行
                if position + 1 < lines.count {
                    let next = lines[position + 1].trimmingCharacters(in: .whitespaces)
                    if next.hasPrefix(">") || next.isEmpty {
                        rawLines.append("")
                        advance()
                        continue
                    }
                }
                break
            } else {
                break
            }
        }

        let innerText = rawLines.joined(separator: "\n")
        var innerParser = MarkdownBlockParser(text: innerText)
        let innerDoc = innerParser.parse()
        if case .document(let children) = innerDoc {
            return .blockQuote(children: children)
        }
        return .blockQuote(children: [])
    }

    private mutating func parseList(ordered: Bool) -> MDNode? {
        var items: [MDNode] = []

        while !isAtEnd {
            let line = currentLine().trimmingCharacters(in: .whitespaces)
            let isItem = ordered ? isOrderedListItem(line) : isUnorderedListItem(line)
            guard isItem else { break }

            // 提取列表项内容（去掉标记）
            let itemContent: String
            if ordered {
                let afterNumber = line.drop(while: { $0.isNumber })
                itemContent = String(afterNumber.dropFirst().trimmingCharacters(in: .whitespaces))
            } else {
                itemContent = String(line.dropFirst().trimmingCharacters(in: .whitespaces))
            }
            advance()

            // 收集后续属于同一项的行（缩进或空行后的续行）
            var continuationLines: [String] = [itemContent]
            while !isAtEnd {
                let raw = currentLine()
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                let nextIsItem = ordered ? isOrderedListItem(trimmed) : isUnorderedListItem(trimmed)

                if trimmed.isEmpty {
                    // 空行：检查下一行是否新列表项
                    if position + 1 < lines.count {
                        let next = lines[position + 1].trimmingCharacters(in: .whitespaces)
                        let nextIsItem2 = ordered ? isOrderedListItem(next) : isUnorderedListItem(next)
                        if nextIsItem2 {
                            advance() // 吞掉空行
                            break
                        }
                    }
                    // 空行后不是新列表项，结束当前项
                    advance()
                    break
                } else if nextIsItem {
                    break
                } else {
                    continuationLines.append(raw)
                    advance()
                }
            }

            let itemText = continuationLines.joined(separator: "\n")
            // 递归解析列表项内部（可能包含段落、子列表等）
            var itemParser = MarkdownBlockParser(text: itemText)
            let itemDoc = itemParser.parse()
            if case .document(let children) = itemDoc {
                items.append(.listItem(children: children))
            } else {
                var fallbackParser = MarkdownInlineParser(text: itemText)
                items.append(.listItem(children: [.paragraph(children: fallbackParser.parse())]))
            }
        }

        return ordered ? .orderedList(items: items) : .unorderedList(items: items)
    }

    private mutating func parseParagraph() -> MDNode? {
        var paraLines: [String] = []
        while !isAtEnd {
            let line = currentLine()
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 空行结束段落
            if trimmed.isEmpty {
                advance()
                break
            }

            // 遇到块级元素也结束
            if isHorizontalRule(trimmed) || trimmed.hasPrefix("```") ||
                trimmed.hasPrefix("#") || trimmed.hasPrefix(">") ||
                isUnorderedListItem(trimmed) || isOrderedListItem(trimmed) {
                break
            }

            paraLines.append(line)
            advance()
        }

        guard !paraLines.isEmpty else { return nil }

        // 检测硬换行：行尾两个空格
        var inlineNodes: [MDNode] = []
        for (i, line) in paraLines.enumerated() {
            let hasHardBreak = line.hasSuffix("  ")
            let content = hasHardBreak ? String(line.dropLast(2)) : line
            var paraInlineParser = MarkdownInlineParser(text: content)
            inlineNodes.append(contentsOf: paraInlineParser.parse())
            if i < paraLines.count - 1 {
                inlineNodes.append(hasHardBreak ? .lineBreak : .softBreak)
            }
        }

        return .paragraph(children: inlineNodes)
    }

    // MARK: - 辅助判断

    private func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return false }
        let first = trimmed.first!
        guard first == "-" || first == "*" || first == "_" else { return false }
        let chars = trimmed.filter { $0 != first && !$0.isWhitespace }
        return chars.isEmpty
    }

    private func isUnorderedListItem(_ line: String) -> Bool {
        guard line.count >= 2 else { return false }
        let first = line.first!
        guard first == "-" || first == "*" || first == "+" else { return false }
        let second = line.dropFirst().first!
        return second.isWhitespace
    }

    private func isOrderedListItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let firstDigit = trimmed.firstIndex(where: { $0.isNumber }) else { return false }
        let afterNumbers = trimmed[firstDigit...].drop(while: { $0.isNumber })
        guard let first = afterNumbers.first else { return false }
        return first == "." && (afterNumbers.count > 1 && afterNumbers.dropFirst().first!.isWhitespace)
    }

    // MARK: - 行迭代器

    private var isAtEnd: Bool { position >= lines.count }

    private func currentLine() -> String {
        guard position < lines.count else { return "" }
        return lines[position]
    }

    private mutating func advance() {
        if position < lines.count { position += 1 }
    }

    private mutating func skipEmptyLines() {
        while !isAtEnd && currentLine().trimmingCharacters(in: .whitespaces).isEmpty {
            advance()
        }
    }
}

// MARK: - 行内解析器

/// Markdown 行内解析器
///
/// 基于 Token 流进行递归下降语法分析，识别粗体、斜体、代码、链接等内联元素。
struct MarkdownInlineParser {
    private let tokens: [MDToken]
    private var position: Int = 0

    init(text: String) {
        let lexer = MarkdownLexer(input: text)
        self.tokens = lexer.tokenize()
    }

    init(tokens: [MDToken]) {
        self.tokens = tokens
    }

    /// 解析行内元素，返回节点数组
    mutating func parse() -> [MDNode] {
        var nodes: [MDNode] = []
        while !isAtEnd {
            if let node = parseInlineNode() {
                nodes.append(node)
            }
        }
        return mergeTextNodes(nodes)
    }

    // MARK: - 递归下降解析

    private mutating func parseInlineNode() -> MDNode? {
        if isAtEnd { return nil }

        // 粗体 ** 或 __
        if let bold = parseDelimited(delimiter: .asterisks(2), node: { children in .bold(children: children) }) ??
           parseDelimited(delimiter: .underscores(2), node: { children in .bold(children: children) }) {
            return bold
        }

        // 删除线 ~~
        if let strike = parseDelimited(delimiter: .tildes(2), node: { children in .strikethrough(children: children) }) {
            return strike
        }

        // 斜体 * 或 _（注意：前面已尝试 ** 和 __，这里只剩单个）
        if let italic = parseDelimited(delimiter: .asterisks(1), node: { children in .italic(children: children) }) ??
           parseDelimited(delimiter: .underscores(1), node: { children in .italic(children: children) }) {
            return italic
        }

        // 行内代码 `
        if let code = parseInlineCode() {
            return code
        }

        // 图片 ![alt](url)
        if let image = parseImage() {
            return image
        }

        // 链接 [text](url)
        if let link = parseLink() {
            return link
        }

        // 块引用 ((id "锚文本"))
        if let blockRef = parseBlockRef() {
            return blockRef
        }

        // 块嵌入 {{id}}
        if let blockEmbed = parseBlockEmbed() {
            return blockEmbed
        }

        // 普通文本或单个特殊符号
        return parseTextOrSymbol()
    }

    /// 通用分隔符包裹解析（用于 **、*、~~、__、_）
    private mutating func parseDelimited(
        delimiter: MDToken,
        node: ([MDNode]) -> MDNode
    ) -> MDNode? {
        guard peek() == delimiter else { return nil }
        let startPos = position
        advance()

        var innerTokens: [MDToken] = []
        while !isAtEnd && peek() != delimiter {
            innerTokens.append(current())
            advance()
        }

        guard !isAtEnd else {
            // 未找到闭合符，回退
            position = startPos
            return nil
        }
        advance() // 吞掉闭合符

        var innerParser = MarkdownInlineParser(tokens: innerTokens)
        let children = innerParser.parse()
        return node(children)
    }

    private mutating func parseInlineCode() -> MDNode? {
        guard case .backticks(let count) = peek(), count == 1 else { return nil }
        advance()

        var content = ""
        while !isAtEnd {
            if case .backticks(let c) = peek(), c == 1 {
                advance()
                break
            }
            content += tokenText(current())
            advance()
        }
        return .inlineCode(content: content)
    }

    private mutating func parseLink() -> MDNode? {
        guard case .openBracket = peek() else { return nil }
        let startPos = position
        advance()

        var linkTextTokens: [MDToken] = []
        while !isAtEnd {
            if case .closeBracket = peek() { break }
            linkTextTokens.append(current())
            advance()
        }
        guard case .closeBracket = peek() else {
            position = startPos; return nil
        }
        advance()

        guard case .openParen = peek() else {
            position = startPos; return nil
        }
        advance()

        var url = ""
        while !isAtEnd {
            if case .closeParen = peek() { break }
            url += tokenText(current())
            advance()
        }
        guard case .closeParen = peek() else {
            position = startPos; return nil
        }
        advance()

        var textParser = MarkdownInlineParser(tokens: linkTextTokens)
        let children = textParser.parse()
        return .link(url: url.trimmingCharacters(in: .whitespaces), children: children)
    }

    private mutating func parseImage() -> MDNode? {
        guard case .bang = peek() else { return nil }
        let startPos = position
        advance()

        guard case .openBracket = peek() else {
            position = startPos; return nil
        }
        advance()

        var altTokens: [MDToken] = []
        while !isAtEnd {
            if case .closeBracket = peek() { break }
            altTokens.append(current())
            advance()
        }
        guard case .closeBracket = peek() else {
            position = startPos; return nil
        }
        advance()

        guard case .openParen = peek() else {
            position = startPos; return nil
        }
        advance()

        var url = ""
        while !isAtEnd {
            if case .closeParen = peek() { break }
            url += tokenText(current())
            advance()
        }
        guard case .closeParen = peek() else {
            position = startPos; return nil
        }
        advance()

        let alt = altTokens.map(tokenText).joined()
        return .image(alt: alt, url: url.trimmingCharacters(in: .whitespaces))
    }

    private mutating func parseBlockRef() -> MDNode? {
        guard case .openDoubleParen = peek() else { return nil }
        let startPos = position
        advance() // 吞掉 ((

        var innerTokens: [MDToken] = []
        while !isAtEnd {
            if case .closeDoubleParen = peek() { break }
            innerTokens.append(current())
            advance()
        }

        guard case .closeDoubleParen = peek() else {
            position = startPos
            return nil
        }
        advance() // 吞掉 ))

        let content = innerTokens.map(tokenText).joined().trimmingCharacters(in: .whitespaces)

        // 解析 id 和可选的锚文本: UUID "锚文本"
        if let firstQuote = content.firstIndex(of: "\"") {
            let idPart = String(content[..<firstQuote]).trimmingCharacters(in: .whitespaces)
            let afterQuote = content.index(after: firstQuote)
            let remaining = String(content[afterQuote...])
            if let lastQuote = remaining.lastIndex(of: "\"") {
                let anchor = String(remaining[..<lastQuote])
                return .blockRef(id: idPart, anchor: anchor.isEmpty ? nil : anchor)
            }
            return .blockRef(id: idPart, anchor: nil)
        }

        return .blockRef(id: content, anchor: nil)
    }

    private mutating func parseBlockEmbed() -> MDNode? {
        guard case .openDoubleBrace = peek() else { return nil }
        let startPos = position
        advance()

        var innerTokens: [MDToken] = []
        while !isAtEnd {
            if case .closeDoubleBrace = peek() { break }
            innerTokens.append(current())
            advance()
        }

        guard case .closeDoubleBrace = peek() else {
            position = startPos
            return nil
        }
        advance()

        let content = innerTokens.map(tokenText).joined().trimmingCharacters(in: .whitespaces)
        return .blockEmbed(id: content)
    }

    private mutating func parseTextOrSymbol() -> MDNode {
        let token = current()
        advance()
        return .text(tokenText(token))
    }

    // MARK: - Token 辅助

    private var isAtEnd: Bool {
        if position >= tokens.count { return true }
        if case .eof = tokens[position] { return true }
        return false
    }

    private func peek() -> MDToken {
        guard position < tokens.count else { return .eof }
        return tokens[position]
    }

    private func current() -> MDToken {
        peek()
    }

    private mutating func advance() {
        if position < tokens.count { position += 1 }
    }

    /// 将单个 Token 还原为原始字符串
    private func tokenText(_ token: MDToken) -> String {
        switch token {
        case .text(let s):          return s
        case .hashes(let n):        return String(repeating: "#", count: n)
        case .asterisks(let n):     return String(repeating: "*", count: n)
        case .underscores(let n):   return String(repeating: "_", count: n)
        case .tildes(let n):        return String(repeating: "~", count: n)
        case .backticks(let n):     return String(repeating: "`", count: n)
        case .openBracket:          return "["
        case .closeBracket:         return "]"
        case .openParen:            return "("
        case .closeParen:           return ")"
        case .openDoubleParen:      return "(("
        case .closeDoubleParen:     return "))"
        case .openDoubleBrace:      return "{{"
        case .closeDoubleBrace:     return "}}"
        case .bang:                 return "!"
        case .gt:                   return ">"
        case .minus:                return "-"
        case .plus:                 return "+"
        case .dot:                  return "."
        case .whitespace(let s):    return s
        case .newline:              return "\n"
        case .eof:                  return ""
        }
    }

    /// 合并相邻的文本节点
    private func mergeTextNodes(_ nodes: [MDNode]) -> [MDNode] {
        var result: [MDNode] = []
        var currentText = ""
        for node in nodes {
            if case .text(let s) = node {
                currentText += s
            } else {
                if !currentText.isEmpty {
                    result.append(.text(currentText))
                    currentText = ""
                }
                result.append(node)
            }
        }
        if !currentText.isEmpty {
            result.append(.text(currentText))
        }
        return result
    }
}

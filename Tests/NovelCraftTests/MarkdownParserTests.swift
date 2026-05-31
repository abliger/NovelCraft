import XCTest
@testable import NovelCraft

/// Markdown 编译原理解析器单元测试
/// 覆盖词法分析、语法分析、AST 结构与异步解析引擎。
final class MarkdownParserTests: XCTestCase {

    // MARK: - Lexer

    func testLexerHeading() {
        let lexer = MarkdownLexer(input: "## 标题")
        let tokens = lexer.tokenize()
        // 行首非空白字符后的空格保留在文本 token 中，不影响后续解析
        XCTAssertEqual(tokens, [
            .hashes(2),
            .text(" 标题"),
            .eof
        ])
    }

    func testLexerBoldItalic() {
        let lexer = MarkdownLexer(input: "**粗体**")
        let tokens = lexer.tokenize()
        XCTAssertEqual(tokens, [
            .asterisks(2),
            .text("粗体"),
            .asterisks(2),
            .eof
        ])
    }

    func testLexerInlineCode() {
        let lexer = MarkdownLexer(input: "`code`")
        let tokens = lexer.tokenize()
        XCTAssertEqual(tokens, [
            .backticks(1),
            .text("code"),
            .backticks(1),
            .eof
        ])
    }

    func testLexerLink() {
        let lexer = MarkdownLexer(input: "[文本](https://example.com)")
        let tokens = lexer.tokenize()
        // `.` 作为特殊符号被单独分词，Parser 阶段会将其重组为完整 URL
        XCTAssertEqual(tokens, [
            .openBracket,
            .text("文本"),
            .closeBracket,
            .openParen,
            .text("https://example"),
            .dot,
            .text("com"),
            .closeParen,
            .eof
        ])
    }

    func testLexerEmpty() {
        let lexer = MarkdownLexer(input: "")
        let tokens = lexer.tokenize()
        XCTAssertEqual(tokens, [.eof])
    }

    // MARK: - Block Parser

    func testParseHeading() {
        let ast = MarkdownParser.parse("# 一级标题\n## 二级标题")
        guard case .document(let children) = ast else {
            XCTFail("根节点应为 document"); return
        }
        XCTAssertEqual(children.count, 2)

        guard case .heading(let level1, let c1) = children[0] else {
            XCTFail("第一个应为 heading"); return
        }
        XCTAssertEqual(level1, 1)
        XCTAssertEqual(c1.plainText(), "一级标题")

        guard case .heading(let level2, let c2) = children[1] else {
            XCTFail("第二个应为 heading"); return
        }
        XCTAssertEqual(level2, 2)
        XCTAssertEqual(c2.plainText(), "二级标题")
    }

    func testParseParagraph() {
        let ast = MarkdownParser.parse("这是一段普通文本。")
        guard case .document(let children) = ast,
              case .paragraph(let para) = children.first else {
            XCTFail("应为段落"); return
        }
        XCTAssertEqual(para.plainText(), "这是一段普通文本。")
    }

    func testParseBoldAndItalic() {
        let ast = MarkdownParser.parse("这是**粗体**和*斜体*。")
        guard case .document(let children) = ast,
              case .paragraph(let para) = children.first else {
            XCTFail("应为段落"); return
        }
        // 应包含 text, bold(text), text, italic(text), text
        XCTAssertTrue(para.contains(where: { if case .bold = $0 { return true }; return false }))
        XCTAssertTrue(para.contains(where: { if case .italic = $0 { return true }; return false }))
    }

    func testParseInlineCode() {
        let ast = MarkdownParser.parse("使用 `print()` 输出。")
        guard case .document(let children) = ast,
              case .paragraph(let para) = children.first else {
            XCTFail("应为段落"); return
        }
        XCTAssertTrue(para.contains(where: { if case .inlineCode = $0 { return true }; return false }))
    }

    func testParseFencedCodeBlock() {
        let input = """
        ```swift
        let x = 1
        ```
        """
        let ast = MarkdownParser.parse(input)
        guard case .document(let children) = ast,
              case .codeBlock(let lang, let content) = children.first else {
            XCTFail("应为代码块"); return
        }
        XCTAssertEqual(lang, "swift")
        XCTAssertEqual(content.trimmingCharacters(in: .whitespacesAndNewlines), "let x = 1")
    }

    func testParseUnorderedList() {
        let ast = MarkdownParser.parse("- 第一项\n- 第二项")
        guard case .document(let children) = ast,
              case .unorderedList(let items) = children.first else {
            XCTFail("应为无序列表"); return
        }
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].plainText, "第一项")
        XCTAssertEqual(items[1].plainText, "第二项")
    }

    func testParseOrderedList() {
        let ast = MarkdownParser.parse("1. 第一项\n2. 第二项")
        guard case .document(let children) = ast,
              case .orderedList(let items) = children.first else {
            XCTFail("应为有序列表"); return
        }
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].plainText, "第一项")
    }

    func testParseBlockQuote() {
        let ast = MarkdownParser.parse("> 引用内容")
        guard case .document(let children) = ast,
              case .blockQuote(let quote) = children.first else {
            XCTFail("应为引用块"); return
        }
        XCTAssertEqual(quote.plainText(), "引用内容")
    }

    func testParseHorizontalRule() {
        let ast = MarkdownParser.parse("---")
        guard case .document(let children) = ast,
              case .horizontalRule = children.first else {
            XCTFail("应为分隔线"); return
        }
        // pass
    }

    func testParseLink() {
        let ast = MarkdownParser.parse("[链接](https://example.com)")
        guard case .document(let children) = ast,
              case .paragraph(let para) = children.first else {
            XCTFail("应为段落"); return
        }
        XCTAssertTrue(para.contains(where: { if case .link = $0 { return true }; return false }))
    }

    func testParseImage() {
        let ast = MarkdownParser.parse("![描述](image.png)")
        guard case .document(let children) = ast,
              case .paragraph(let para) = children.first else {
            XCTFail("应为段落"); return
        }
        XCTAssertTrue(para.contains(where: { if case .image = $0 { return true }; return false }))
    }

    func testParseStrikethrough() {
        let ast = MarkdownParser.parse("~~删除线~~")
        guard case .document(let children) = ast,
              case .paragraph(let para) = children.first else {
            XCTFail("应为段落"); return
        }
        var desc = ""
        for node in para {
            switch node {
            case .strikethrough: desc += "strikethrough "
            case .text(let t): desc += "text(\(t)) "
            case .bold: desc += "bold "
            case .italic: desc += "italic "
            default: desc += "other "
            }
        }
        XCTAssertTrue(para.contains(where: { if case .strikethrough = $0 { return true }; return false }), "实际节点: \(desc)")
    }

    func testComplexDocument() {
        let input = """
        # 小说标题

        这是开篇段落，包含**粗体**和*斜体*。

        > 引用一段文字

        - 列表项一
        - 列表项二

        ```
        代码块内容
        ```
        """
        let ast = MarkdownParser.parse(input)
        guard case .document(let children) = ast else {
            XCTFail("应为 document"); return
        }
        var types: [String] = []
        for child in children {
            switch child {
            case .heading: types.append("heading")
            case .paragraph: types.append("paragraph")
            case .blockQuote: types.append("blockQuote")
            case .unorderedList: types.append("unorderedList")
            case .orderedList: types.append("orderedList")
            case .codeBlock: types.append("codeBlock")
            case .horizontalRule: types.append("horizontalRule")
            default: types.append("other")
            }
        }
        XCTAssertTrue(children.contains(where: { if case .heading = $0 { return true }; return false }), "节点类型: \(types)")
        XCTAssertTrue(children.contains(where: { if case .paragraph = $0 { return true }; return false }), "节点类型: \(types)")
        XCTAssertTrue(children.contains(where: { if case .blockQuote = $0 { return true }; return false }), "节点类型: \(types)")
        XCTAssertTrue(children.contains(where: { if case .unorderedList = $0 { return true }; return false }), "节点类型: \(types)")
        XCTAssertTrue(children.contains(where: { if case .codeBlock = $0 { return true }; return false }), "节点类型: \(types)")
    }

    // MARK: - Async Engine

    func testAsyncParse() async {
        let engine = MarkdownAsyncEngine()
        let ast = await engine.parse("# 异步标题\n\n段落内容")
        guard case .document(let children) = ast else {
            XCTFail("应为 document"); return
        }
        XCTAssertTrue(children.contains(where: { if case .heading = $0 { return true }; return false }))
    }

    func testAsyncBatchParse() async {
        let engine = MarkdownAsyncEngine()
        let results = await engine.parseFiles([
            "# 文档一",
            "## 文档二"
        ])
        XCTAssertEqual(results.count, 2)
        for doc in results {
            guard case .document = doc else {
                XCTFail("应为 document"); return
            }
        }
    }

    // MARK: - 双向链接 / 内容块

    func testLexerBlockRef() {
        let lexer = MarkdownLexer(input: "((550e8400-e29b-41d4-a716-446655440000 \"锚文本\"))")
        let tokens = lexer.tokenize()
        XCTAssertTrue(tokens.contains(.openDoubleParen))
        XCTAssertTrue(tokens.contains(.closeDoubleParen))
    }

    func testLexerBlockEmbed() {
        let lexer = MarkdownLexer(input: "{{550e8400-e29b-41d4-a716-446655440000}}")
        let tokens = lexer.tokenize()
        XCTAssertTrue(tokens.contains(.openDoubleBrace))
        XCTAssertTrue(tokens.contains(.closeDoubleBrace))
    }

    func testParseBlockRef() {
        let ast = MarkdownParser.parse("这是((550e8400-e29b-41d4-a716-446655440000 \"引用\"))的内容。")
        guard case .document(let children) = ast,
              case .paragraph(let para) = children.first else {
            XCTFail("应为段落"); return
        }
        XCTAssertTrue(para.contains(where: { if case .blockRef = $0 { return true }; return false }))
    }

    func testParseBlockEmbed() {
        let ast = MarkdownParser.parse("这是{{550e8400-e29b-41d4-a716-446655440000}}的内容。")
        guard case .document(let children) = ast,
              case .paragraph(let para) = children.first else {
            XCTFail("应为段落"); return
        }
        XCTAssertTrue(para.contains(where: { if case .blockEmbed = $0 { return true }; return false }))
    }

    func testBlockRefPlainText() {
        let ast = MarkdownParser.parse("((550e8400-e29b-41d4-a716-446655440000 \"锚文本\"))")
        guard case .document(let children) = ast,
              case .paragraph(let para) = children.first,
              case .blockRef(_, let anchor) = para.first else {
            XCTFail("应为 blockRef"); return
        }
        XCTAssertEqual(anchor, "锚文本")
        XCTAssertEqual(para.first?.plainText, "锚文本")
    }

    func testBlockRefEngineScan() {
        let text = "章节A引用了((id-1 \"第一章\"))和((id-2))，还嵌入了{{id-3}}。"
        let refs = BlockRefEngine.scanRefs(in: text)
        XCTAssertEqual(refs.count, 3)
        XCTAssertEqual(refs[0].targetID, "id-1")
        XCTAssertEqual(refs[0].anchor, "第一章")
        XCTAssertFalse(refs[0].isEmbed)
        XCTAssertEqual(refs[1].targetID, "id-2")
        XCTAssertNil(refs[1].anchor)
        XCTAssertEqual(refs[2].targetID, "id-3")
        XCTAssertTrue(refs[2].isEmbed)
    }
}

// MARK: - 辅助扩展

private extension Sequence where Element == MDNode {
    func plainText() -> String {
        self.map(\.plainText).joined()
    }

    func contains(where predicate: (MDNode) -> Bool) -> Bool {
        for element in self {
            if predicate(element) { return true }
        }
        return false
    }
}

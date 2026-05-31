import XCTest
@testable import NovelCraft

final class HTMLRendererTests: XCTestCase {
    func testRenderBasicMarkdown() {
        let markdown = "# Hello\n\nThis is **bold** and *italic*."
        let html = HTMLRenderer.renderFullPage(from: markdown)
        XCTAssertTrue(html.contains("<h1>Hello</h1>"), "Should contain heading")
        XCTAssertTrue(html.contains("<strong>bold</strong>"), "Should contain bold")
        XCTAssertTrue(html.contains("<em>italic</em>"), "Should contain italic")
        XCTAssertTrue(html.contains("{{MATHJAX_URL}}"), "Should include MathJax placeholder")
        XCTAssertTrue(html.contains("{{MERMAID_URL}}"), "Should include Mermaid placeholder")
        XCTAssertTrue(html.contains("{{ABCJS_URL}}"), "Should include abcjs placeholder")
    }
    
    func testRenderMathBlock() {
        let markdown = "```math\nE = mc^2\n```"
        let html = HTMLRenderer.renderFullPage(from: markdown)
        XCTAssertTrue(html.contains("<div class=\"math\">"), "Should render math div")
        XCTAssertTrue(html.contains("E = mc^2"), "Should contain formula")
    }
    
    func testRenderMermaidBlock() {
        let markdown = "```mermaid\ngraph TD\n    A --> B\n```"
        let html = HTMLRenderer.renderFullPage(from: markdown)
        XCTAssertTrue(html.contains("<div class=\"mermaid\">"), "Should render mermaid div")
        XCTAssertTrue(html.contains("graph TD"), "Should contain mermaid syntax")
    }
    
    func testRenderABCBlock() {
        let markdown = "```abc\nX:1\nT:Test\nK:C\nCDEF|\n```"
        let html = HTMLRenderer.renderFullPage(from: markdown)
        XCTAssertTrue(html.contains("<div class=\"abc-music\">"), "Should render abc div")
    }
    
    func testRenderHTMLBlock() {
        let markdown = "```html\n<svg width=\"100\"><circle cx=\"50\" cy=\"50\" r=\"40\"/></svg>\n```"
        let html = HTMLRenderer.renderFullPage(from: markdown)
        XCTAssertTrue(html.contains("<svg"), "Should contain raw SVG")
        XCTAssertFalse(html.contains("&lt;svg"), "Should not escape SVG")
    }
    
    func testAsyncHTMLRendering() async {
        let markdown = "# Test\n\nHello world."
        let html = await MarkdownParser.htmlAsync(from: markdown)
        XCTAssertTrue(html.contains("<h1>Test</h1>"))
        XCTAssertTrue(html.contains("<p>Hello world.</p>"))
    }
}

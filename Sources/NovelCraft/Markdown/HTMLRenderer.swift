import Foundation

/// Markdown AST → HTML 渲染器
///
/// 支持以下特殊代码块语言：
/// - `math` / `latex` → MathJax 渲染
/// - `mermaid` → Mermaid 图表（流程图、时序图、甘特图等）
/// - `abc` → ABC 五线谱（abcjs 渲染）
/// - `html` → 原始 HTML 直接嵌入（支持 SVG 等）
struct HTMLRenderer {
    let baseURL: URL?
    
    init(baseURL: URL? = nil) {
        self.baseURL = baseURL
    }
    
    static func render(_ node: MDNode) -> String {
        let renderer = HTMLRenderer()
        return renderer.render(node)
    }
    
    private func render(_ node: MDNode) -> String {
        switch node {
        case .document(let children):
            return children.map(render).joined()
            
        case .heading(let level, let children):
            let tag = "h\(level)"
            return "<\(tag)>\(children.map(render).joined())</\(tag)>\n"
            
        case .paragraph(let children):
            return "<p>\(children.map(render).joined())</p>\n"
            
        case .text(let content):
            return escapeHTML(content)
            
        case .bold(let children):
            return "<strong>\(children.map(render).joined())</strong>"
            
        case .italic(let children):
            return "<em>\(children.map(render).joined())</em>"
            
        case .strikethrough(let children):
            return "<del>\(children.map(render).joined())</del>"
            
        case .codeBlock(let language, let content):
            return renderCodeBlock(language: language, content: content)
            
        case .inlineCode(let content):
            return "<code>\(escapeHTML(content))</code>"
            
        case .link(let url, let children):
            return "<a href=\"\(escapeHTML(url))\">\(children.map(render).joined())</a>"
            
        case .image(let alt, let url):
            let resolvedURL = resolveImageURL(url)
            return "<img src=\"\(escapeHTML(resolvedURL))\" alt=\"\(escapeHTML(alt))\">"
            
        case .orderedList(let items):
            return "<ol>\n\(items.map(render).joined())</ol>\n"
            
        case .unorderedList(let items):
            return "<ul>\n\(items.map(render).joined())</ul>\n"
            
        case .listItem(let children):
            return "<li>\(children.map(render).joined())</li>\n"
            
        case .blockQuote(let children):
            return "<blockquote>\n\(children.map(render).joined())</blockquote>\n"
            
        case .horizontalRule:
            return "<hr>\n"
            
        case .lineBreak:
            return "<br>\n"
            
        case .softBreak:
            return " "
            
        case .blockRef(_, let anchor):
            let display = anchor?.isEmpty == false ? anchor! : "引用"
            return "<span class=\"block-ref\">\(escapeHTML(display))</span>"
            
        case .blockEmbed(_):
            return "<span class=\"block-embed\">[嵌入块]</span>"
        }
    }
    
    private func renderCodeBlock(language: String?, content: String) -> String {
        let lang = language?.lowercased() ?? ""
        switch lang {
        case "math", "latex":
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("$$") && trimmed.hasSuffix("$$") {
                return "<div class=\"math\">\(trimmed)</div>\n"
            } else if trimmed.hasPrefix("$") && trimmed.hasSuffix("$") {
                return "<p class=\"math\">\(trimmed)</p>\n"
            } else {
                return "<div class=\"math\">\\[\(trimmed)\\]</div>\n"
            }
        case "mermaid":
            return "<div class=\"mermaid\">\(content)</div>\n"
        case "abc":
            return "<div class=\"abc-music\">\(content)</div>\n"
        case "html":
            return "\(content)\n"
        default:
            let langClass = lang.isEmpty ? "" : " class=\"language-\(escapeHTML(lang))\""
            return "<pre><code\(langClass)>\(escapeHTML(content))</code></pre>\n"
        }
    }
    
    private func resolveImageURL(_ url: String) -> String {
        if url.hasPrefix("http") || url.hasPrefix("file://") || url.hasPrefix("data:") {
            return url
        }
        if let baseURL = baseURL {
            return baseURL.appendingPathComponent(url).absoluteString
        }
        return url
    }
    
    private func escapeHTML(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        return result
    }
}

// MARK: - 完整 HTML 页面包装

extension HTMLRenderer {
    /// 将 Markdown AST 渲染为包含 MathJax / Mermaid / abcjs 的完整 HTML 页面
    static func renderFullPage(_ node: MDNode, baseURL: URL? = nil) -> String {
        let renderer = HTMLRenderer(baseURL: baseURL)
        let body = renderer.render(node)
        return htmlTemplate.replacingOccurrences(of: "<!-- CONTENT -->", with: body)
    }
    
    /// 将 Markdown 文本直接渲染为完整 HTML 页面
    static func renderFullPage(from markdown: String, baseURL: URL? = nil) -> String {
        let ast = MarkdownParser.parse(markdown)
        return renderFullPage(ast, baseURL: baseURL)
    }
    
    private static let htmlTemplate = """
    <!DOCTYPE html>
    <html lang="zh-CN">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
    body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
        line-height: 1.6;
        padding: 24px;
        max-width: 860px;
        margin: 0 auto;
        color: #24292f;
        background: #ffffff;
    }
    h1, h2, h3, h4, h5, h6 { margin-top: 24px; margin-bottom: 16px; font-weight: 600; line-height: 1.25; }
    h1 { font-size: 2em; border-bottom: 1px solid #d0d7de; padding-bottom: 0.3em; }
    h2 { font-size: 1.5em; border-bottom: 1px solid #d0d7de; padding-bottom: 0.3em; }
    h3 { font-size: 1.25em; }
    h4 { font-size: 1em; }
    h5 { font-size: 0.875em; }
    h6 { font-size: 0.85em; color: #57606a; }
    p { margin-top: 0; margin-bottom: 16px; }
    pre {
        background: #f6f8fa;
        padding: 16px;
        border-radius: 6px;
        overflow-x: auto;
        font-size: 85%;
        line-height: 1.45;
    }
    code {
        font-family: SFMono-Regular, Consolas, "Liberation Mono", Menlo, Courier, monospace;
        background: rgba(175,184,193,0.2);
        padding: 0.2em 0.4em;
        border-radius: 3px;
        font-size: 85%;
    }
    pre code { background: transparent; padding: 0; font-size: 100%; }
    blockquote {
        border-left: 4px solid #d0d7de;
        padding-left: 16px;
        color: #57606a;
        margin: 0 0 16px 0;
    }
    img { max-width: 100%; box-sizing: border-box; }
    table { border-collapse: collapse; width: 100%; margin: 16px 0; }
    th, td { border: 1px solid #d0d7de; padding: 6px 13px; }
    th { background: #f6f8fa; font-weight: 600; }
    tr:nth-child(2n) { background: #f6f8fa; }
    hr { border: 0; border-top: 1px solid #d0d7de; margin: 24px 0; }
    a { color: #0969da; text-decoration: none; }
    a:hover { text-decoration: underline; }
    ul, ol { margin-top: 0; margin-bottom: 16px; padding-left: 2em; }
    li + li { margin-top: 0.25em; }
    .math { overflow-x: auto; }
    .mermaid { text-align: center; margin: 16px 0; }
    .abc-music { text-align: center; margin: 16px 0; }
    .block-ref {
        color: #8250df;
        background: #f5f0ff;
        padding: 2px 4px;
        border-radius: 3px;
        font-weight: 500;
    }
    .block-embed {
        color: #0969da;
        background: #ddf4ff;
        padding: 2px 4px;
        border-radius: 3px;
        font-weight: 500;
    }
    </style>
    <script>
    window.MathJax = {
        tex: {
            inlineMath: [['$', '$'], ['\\(', '\\)']],
            displayMath: [['$$', '$$'], ['\\[', '\\]']],
            processEscapes: true
        },
        svg: { fontCache: 'global' }
    };
    </script>
    <script src="{{MATHJAX_URL}}"></script>
    <script src="{{MERMAID_URL}}"></script>
    <script src="{{ABCJS_URL}}"></script>
    <script>
    function initPreviewLibraries() {
        if (typeof mermaid !== 'undefined') {
            mermaid.initialize({ startOnLoad: false, theme: 'default' });
            mermaid.run({ querySelector: '.mermaid' });
        }
        if (typeof ABCJS !== 'undefined') {
            document.querySelectorAll('.abc-music').forEach(function(el) {
                ABCJS.renderAbc(el, el.textContent);
            });
        }
    }
    document.addEventListener('DOMContentLoaded', initPreviewLibraries);
    window.addEventListener('load', initPreviewLibraries);
    </script>
    </head>
    <body>
    <!-- CONTENT -->
    </body>
    </html>
    """
}

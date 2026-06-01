import SwiftUI
import WebKit

/// 基于 WKWebView 的 Markdown 预览视图
///
/// 加载包含 MathJax、Mermaid、abcjs 的 HTML 页面，支持数学公式、
/// 流程图、时序图、甘特图、五线谱、SVG 图片和原始 HTML 的渲染。
///
/// 使用 loadHTMLString 加载，baseURL 指向项目目录，确保相对路径图片能正确加载。
#if os(macOS)
struct PreviewWebView: NSViewRepresentable {
    let htmlString: String
    var baseURL: URL? = nil
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let resolvedHTML = resolveScriptURLs(in: htmlString)
        webView.loadHTMLString(resolvedHTML, baseURL: baseURL)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        let id = UUID().uuidString
    }
    
    /// 将 HTML 模板中的 {{MATHJAX_URL}} 等占位符替换为 CDN 链接或 Bundle 中的本地文件
    private func resolveScriptURLs(in html: String) -> String {
        var result = html
        
        let replacements: [(placeholder: String, resource: String, ext: String, subdir: String)] = [
            ("{{MATHJAX_URL}}", "mathjax", "js", "js"),
            ("{{MERMAID_URL}}", "mermaid", "js", "js"),
            ("{{ABCJS_URL}}", "abcjs", "js", "js"),
        ]
        
        for item in replacements {
            if let url = Bundle.main.url(forResource: item.resource, withExtension: item.ext, subdirectory: item.subdir) {
                result = result.replacingOccurrences(of: item.placeholder, with: url.absoluteString)
            } else {
                // Bundle 中不存在时清空 script 标签，避免加载当前页面作为 JS
                result = result.replacingOccurrences(of: "<script src=\"\(item.placeholder)\"></script>", with: "")
            }
        }
        
        return result
    }
}
#else
struct PreviewWebView: UIViewRepresentable {
    let htmlString: String
    var baseURL: URL? = nil
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let resolvedHTML = resolveScriptURLs(in: htmlString)
        webView.loadHTMLString(resolvedHTML, baseURL: baseURL)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        let id = UUID().uuidString
    }
    
    private func resolveScriptURLs(in html: String) -> String {
        var result = html
        
        let replacements: [(placeholder: String, resource: String, ext: String, subdir: String)] = [
            ("{{MATHJAX_URL}}", "mathjax", "js", "js"),
            ("{{MERMAID_URL}}", "mermaid", "js", "js"),
            ("{{ABCJS_URL}}", "abcjs", "js", "js"),
        ]
        
        for item in replacements {
            if let url = Bundle.main.url(forResource: item.resource, withExtension: item.ext, subdirectory: item.subdir) {
                result = result.replacingOccurrences(of: item.placeholder, with: url.absoluteString)
            } else {
                result = result.replacingOccurrences(of: "<script src=\"\(item.placeholder)\"></script>", with: "")
            }
        }
        
        return result
    }
}
#endif

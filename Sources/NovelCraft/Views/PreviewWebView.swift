import SwiftUI
import WebKit

/// 基于 WKWebView 的 Markdown 预览视图
///
/// 加载包含 MathJax、Mermaid、abcjs 的 HTML 页面，支持数学公式、
/// 流程图、时序图、甘特图、五线谱、SVG 图片和原始 HTML 的渲染。
///
/// 使用 loadFileURL 加载本地 HTML 文件，确保相对路径图片和本地 JS 库都能正确加载。
#if os(macOS)
struct PreviewWebView: NSViewRepresentable {
    let htmlString: String
    var baseURL: URL? = nil
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.preferences.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        let webView = WKWebView(frame: .zero, configuration: config)
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let projectURL = baseURL ?? FileManager.default.temporaryDirectory
        let tempFile = projectURL.appendingPathComponent(".novelcraft_preview_\(context.coordinator.id).html")
        
        let resolvedHTML = resolveScriptURLs(in: htmlString)
        
        do {
            try resolvedHTML.write(to: tempFile, atomically: true, encoding: .utf8)
            webView.loadFileURL(tempFile, allowingReadAccessTo: projectURL)
        } catch {
            webView.loadHTMLString(resolvedHTML, baseURL: baseURL)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        let id = UUID().uuidString
    }
    
    /// 将 HTML 模板中的 {{MATHJAX_URL}} 等占位符替换为 Bundle 中 JS 文件的实际 file:// URL
    private func resolveScriptURLs(in html: String) -> String {
        var result = html
        
        let replacements: [(placeholder: String, resource: String, ext: String, subdir: String)] = [
            ("{{MATHJAX_URL}}", "mathjax", "js", "js"),
            ("{{MERMAID_URL}}", "mermaid", "js", "js"),
            ("{{ABCJS_URL}}", "abcjs", "js", "js"),
        ]
        
        for item in replacements {
            let url = Bundle.main.url(forResource: item.resource, withExtension: item.ext, subdirectory: item.subdir)
            let path = url?.absoluteString ?? ""
            result = result.replacingOccurrences(of: item.placeholder, with: path)
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
        config.preferences.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        let webView = WKWebView(frame: .zero, configuration: config)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let projectURL = baseURL ?? FileManager.default.temporaryDirectory
        let tempFile = projectURL.appendingPathComponent(".novelcraft_preview_\(context.coordinator.id).html")
        
        let resolvedHTML = resolveScriptURLs(in: htmlString)
        
        do {
            try resolvedHTML.write(to: tempFile, atomically: true, encoding: .utf8)
            webView.loadFileURL(tempFile, allowingReadAccessTo: projectURL)
        } catch {
            webView.loadHTMLString(resolvedHTML, baseURL: baseURL)
        }
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
            let url = Bundle.main.url(forResource: item.resource, withExtension: item.ext, subdirectory: item.subdir)
            let path = url?.absoluteString ?? ""
            result = result.replacingOccurrences(of: item.placeholder, with: path)
        }
        
        return result
    }
}
#endif

import Foundation

// MARK: - 文件名处理

extension String {
    /// 清理文件名中的非法字符，防止路径遍历和无效文件名。
    func sanitizedFileName() -> String {
        var result = trimmingCharacters(in: .whitespacesAndNewlines)
        let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|.")
        result = result.components(separatedBy: invalidChars).joined(separator: "-")
        result = result.replacingOccurrences(of: "..", with: "-")
        if result.hasPrefix("-") {
            result = "_" + result
        }
        if result.isEmpty {
            result = "未命名"
        }
        return result
    }
}

// MARK: - HTML/XML 转义

extension String {
    /// 对文本中的 HTML 特殊字符进行转义。
    func escapingHTML() -> String {
        var result = self
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&#39;")
        return result
    }
    
    /// 对文本中的 XML 特殊字符进行转义（包含引号）。
    func escapingXML() -> String {
        var result = self
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&apos;")
        return result
    }
}

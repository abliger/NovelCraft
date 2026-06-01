import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import ZIPFoundation

/// 清理文件名中的危险字符，防止路径遍历和无效文件名。
/// 委托给 `String.sanitizedFileName()` 以保持单一实现。
func sanitizeFileName(_ name: String) -> String {
    let sanitized = name.sanitizedFileName()
    // 扩展方法默认返回 "未命名"，全局函数要求导出场景下返回 "未命名导出"
    return sanitized == "未命名" ? "未命名导出" : sanitized
}

/// 导出范围枚举，指定导出当前章节或整本小说。
enum ExportScope {
    case chapter
    case fullProject
}

/// 导出过程中可能发生的错误类型。
enum ExportError: Error {
    case failedToCreateFile
    case failedToWrite
    case unsupportedFormat
    case zipFailed
    case noChapterSelected
}

/// 导出数据快照，将 SwiftData 模型中的数据提取为值类型，确保线程安全。
struct ExportProjectSnapshot {
    let title: String
    let author: String
    let summary: String
    let chapterTitle: String?
    let chapterContent: String?
    let volumes: [ExportVolumeSnapshot]
}

struct ExportVolumeSnapshot {
    let title: String
    let order: Int
    let chapters: [ExportChapterSnapshot]
}

struct ExportChapterSnapshot {
    let title: String
    let order: Int
    let content: String
}

/// 导出引擎，负责将项目或章节内容导出为 Markdown、纯文本、PDF 或 EPUB 格式。
///
/// 内部使用值类型快照存储数据，可在任意线程（如后台 Task）安全使用。
struct ExportEngine {
    private let snapshot: ExportProjectSnapshot
    
    init(project: Project, chapter: Chapter?) {
        self.snapshot = ExportProjectSnapshot(
            title: project.title,
            author: project.author,
            summary: project.summary,
            chapterTitle: chapter?.title,
            chapterContent: chapter?.content,
            volumes: project.volumes.sorted { $0.order < $1.order }.map { volume in
                ExportVolumeSnapshot(
                    title: volume.title,
                    order: volume.order,
                    chapters: volume.chapters.sorted { $0.order < $1.order }.map { ch in
                        ExportChapterSnapshot(title: ch.title, order: ch.order, content: ch.content)
                    }
                )
            }
        )
    }
    
    /// 执行导出操作，将内容写入临时目录并返回生成的文件 URL。
    func export(format: ExportFormat, scope: ExportScope, includeMetadata: Bool) throws -> URL {
        if scope == .chapter && snapshot.chapterTitle == nil {
            throw ExportError.noChapterSelected
        }
        
        let content = generateContent(scope: scope, includeMetadata: includeMetadata)
        let fileName = generateFileName(format: format, scope: scope)
        
        let tempDir = FileManager.default.temporaryDirectory
        let uniqueFileName = "\(UUID().uuidString)-\(fileName)"
        let fileURL = tempDir.appendingPathComponent(uniqueFileName)
        
        switch format {
        case .markdown:
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        case .plainText:
            let plainText = stripMarkdown(content)
            try plainText.write(to: fileURL, atomically: true, encoding: .utf8)
        case .pdf:
            try generatePDF(content: content, to: fileURL)
        case .epub:
            try generateEPUB(content: content, to: fileURL, includeMetadata: includeMetadata)
        }
        
        return fileURL
    }
    
    /// 根据导出范围与是否包含元数据，生成完整的 Markdown 文本内容。
    private func generateContent(scope: ExportScope, includeMetadata: Bool) -> String {
        var parts: [String] = []
        
        if includeMetadata {
            parts.append("# \(snapshot.title)")
            if !snapshot.author.isEmpty {
                parts.append("**作者**: \(snapshot.author)")
            }
            if !snapshot.summary.isEmpty {
                parts.append("**简介**: \(snapshot.summary)")
            }
            parts.append("")
            parts.append("---")
            parts.append("")
        }
        
        switch scope {
        case .chapter:
            if let title = snapshot.chapterTitle, let content = snapshot.chapterContent {
                parts.append("## \(title)")
                parts.append(content)
            }
        case .fullProject:
            for volume in snapshot.volumes {
                parts.append("# \(volume.title)")
                parts.append("")
                for chapter in volume.chapters {
                    parts.append("## \(chapter.title)")
                    parts.append(chapter.content)
                    parts.append("")
                }
            }
        }
        
        return parts.joined(separator: "\n")
    }
    
    /// 根据导出格式与范围生成安全的文件名。
    private func generateFileName(format: ExportFormat, scope: ExportScope) -> String {
        let baseName: String
        switch scope {
        case .chapter:
            baseName = snapshot.chapterTitle ?? "chapter"
        case .fullProject:
            baseName = snapshot.title
        }
        let sanitized = sanitizeFileName(baseName)
        return "\(sanitized).\(format.fileExtension)"
    }
    
    // MARK: - 静态正则常量，避免每次调用重复编译

    private static let heading1Regex = try! NSRegularExpression(pattern: "^# ", options: .anchorsMatchLines)
    private static let heading2Regex = try! NSRegularExpression(pattern: "^## ", options: .anchorsMatchLines)
    private static let heading3Regex = try! NSRegularExpression(pattern: "^### ", options: .anchorsMatchLines)
    private static let heading4Regex = try! NSRegularExpression(pattern: "^#### ", options: .anchorsMatchLines)
    private static let heading5Regex = try! NSRegularExpression(pattern: "^##### ", options: .anchorsMatchLines)
    private static let heading6Regex = try! NSRegularExpression(pattern: "^###### ", options: .anchorsMatchLines)
    private static let codeFenceRegex = try! NSRegularExpression(pattern: "^```\\s*$", options: .anchorsMatchLines)
    private static let quoteRegex = try! NSRegularExpression(pattern: "^> ", options: .anchorsMatchLines)
    private static let listRegex = try! NSRegularExpression(pattern: "^- ", options: .anchorsMatchLines)
    private static let hrRegex = try! NSRegularExpression(pattern: "^---\\s*$", options: .anchorsMatchLines)
    private static let boldRegex = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: .dotMatchesLineSeparators)
    private static let italicRegex = try! NSRegularExpression(pattern: "\\*(.+?)\\*", options: .dotMatchesLineSeparators)
    private static let blockRefAnchorRegex = try! NSRegularExpression(pattern: #"\(\([^)]+\"([^\"]+)\"\)\)"#, options: [])
    private static let blockRefRegex = try! NSRegularExpression(pattern: #"\(\([^)]+\)\)"#, options: [])
    private static let blockEmbedRegex = try! NSRegularExpression(pattern: #"\{\{[^}]+\}\}"#, options: [])

    /// 去除 Markdown 标记符号，转换为纯文本。
    private func stripMarkdown(_ text: String) -> String {
        var result = text
        // 使用预编译的正则表达式，避免重复编译开销
        result = Self.heading1Regex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count), withTemplate: "")
        result = Self.heading2Regex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count), withTemplate: "")
        result = Self.heading3Regex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count), withTemplate: "")
        result = Self.heading4Regex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count), withTemplate: "")
        result = Self.heading5Regex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count), withTemplate: "")
        result = Self.heading6Regex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count), withTemplate: "")
        result = Self.codeFenceRegex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count), withTemplate: "")
        result = Self.quoteRegex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count), withTemplate: "")
        result = Self.listRegex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count), withTemplate: "• ")
        result = Self.hrRegex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count), withTemplate: "")
        result = Self.boldRegex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count), withTemplate: "$1")
        result = Self.italicRegex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count), withTemplate: "$1")
        result = stripBlockRefs(result)
        return result
    }
    
    /// 将块引用 ((id "锚文本")) 和嵌入 {{id}} 转换为纯文本。
    private func stripBlockRefs(_ text: String) -> String {
        var result = text
        let nsRange = NSRange(location: 0, length: result.utf16.count)
        // ((id "锚文本")) -> 锚文本
        let matches = Self.blockRefAnchorRegex.matches(in: result, options: [], range: nsRange)
        for match in matches.reversed() {
            if let anchorRange = Range(match.range(at: 1), in: result) {
                let anchor = String(result[anchorRange])
                result = (result as NSString).replacingCharacters(in: match.range, with: anchor)
            }
        }
        // ((id)) -> [引用]
        result = Self.blockRefRegex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count), withTemplate: "[引用]")
        // {{id}} -> [嵌入]
        result = Self.blockEmbedRegex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count), withTemplate: "[嵌入]")
        return result
    }
    
    /// 根据当前平台（macOS / iOS）调用对应的 PDF 生成方法。
    private func generatePDF(content: String, to url: URL) throws {
        #if canImport(AppKit)
        try generatePDFMacOS(content: content, to: url)
        #elseif canImport(UIKit)
        try generatePDFiOS(content: content, to: url)
        #else
        throw ExportError.unsupportedFormat
        #endif
    }
    
    #if canImport(AppKit)
    /// 在 macOS 上使用 AppKit 与 Core Graphics 生成 PDF 文件。
    private func generatePDFMacOS(content: String, to url: URL) throws {
        let plainText = stripMarkdown(content)
        let textStorage = NSTextStorage(string: plainText)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 468, height: CGFloat.greatestFiniteMagnitude))
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]
        textStorage.setAttributes(attributes, range: NSRange(location: 0, length: textStorage.length))
        
        var bounds = layoutManager.usedRect(for: textContainer)
        bounds.size.width = 612
        bounds.size.height += 144
        
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw ExportError.failedToCreateFile
        }
        
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: bounds.height)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.failedToCreateFile
        }
        
        context.beginPDFPage(nil)
        context.translateBy(x: 72, y: bounds.height - 72)
        context.scaleBy(x: 1, y: -1)
        layoutManager.drawGlyphs(forGlyphRange: NSRange(location: 0, length: textStorage.length), at: .zero)
        context.endPDFPage()
        context.closePDF()
        
        try pdfData.write(to: url)
    }
    #endif
    
    #if canImport(UIKit)
    /// 在 iOS 上使用 UIKit 的 PDF 绘图上下文生成 PDF 文件。
    private func generatePDFiOS(content: String, to url: URL) throws {
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: 612, height: 792), nil)
        
        guard UIGraphicsGetCurrentContext() != nil else {
            UIGraphicsEndPDFContext()
            throw ExportError.failedToCreateFile
        }
        
        defer { UIGraphicsEndPDFContext() }
        
        UIGraphicsBeginPDFPage()
        
        let textRect = CGRect(x: 72, y: 72, width: 468, height: 648)
        let plainText = stripMarkdown(content)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        let attributedString = NSAttributedString(string: plainText, attributes: attributes)
        attributedString.draw(in: textRect)
        
        try pdfData.write(to: url)
    }
    #endif
    
    /// 生成标准 EPUB 3.0 文件，包含 mimetype、META-INF/container.xml、OEBPS/content.opf 与章节 HTML。
    private func generateEPUB(content: String, to url: URL, includeMetadata: Bool) throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        
        let mimetypeURL = tempDir.appendingPathComponent("mimetype")
        try "application/epub+zip".write(to: mimetypeURL, atomically: true, encoding: .utf8)
        
        let metaInfDir = tempDir.appendingPathComponent("META-INF")
        try fileManager.createDirectory(at: metaInfDir, withIntermediateDirectories: true)
        let containerXML = """
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
    <rootfiles>
        <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
    </rootfiles>
</container>
"""
        try containerXML.write(to: metaInfDir.appendingPathComponent("container.xml"), atomically: true, encoding: .utf8)
        
        let oebpsDir = tempDir.appendingPathComponent("OEBPS")
        try fileManager.createDirectory(at: oebpsDir, withIntermediateDirectories: true)
        
        let htmlContent = convertToHTML(content)
        let chapterHTML = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>\(escapeXML(snapshot.title))</title>
    <meta charset="UTF-8"/>
</head>
<body>
    \(htmlContent)
</body>
</html>
"""
        try chapterHTML.write(to: oebpsDir.appendingPathComponent("chapter.xhtml"), atomically: true, encoding: .utf8)
        
        let opf = """
<?xml version="1.0" encoding="UTF-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf">
    <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>\(escapeXML(snapshot.title))</dc:title>
        <dc:creator>\(escapeXML(snapshot.author))</dc:creator>
        <dc:language>zh-CN</dc:language>
    </metadata>
    <manifest>
        <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
    </manifest>
    <spine>
        <itemref idref="chapter"/>
    </spine>
</package>
"""
        try opf.write(to: oebpsDir.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)
        
        try zipDirectory(tempDir, to: url)
    }
    
    /// 使用 ZIPFoundation 将临时目录打包为 EPUB 文件（纯 Swift，跨平台）。
    private func zipDirectory(_ source: URL, to destination: URL) throws {
        let archive = try Archive(url: destination, accessMode: .create)
        
        let fileManager = FileManager.default
        
        // EPUB 规范要求 mimetype 必须是 ZIP 中的第一个文件且未压缩
        let mimetypeURL = source.appendingPathComponent("mimetype")
        if fileManager.fileExists(atPath: mimetypeURL.path) {
            try archive.addEntry(with: "mimetype", relativeTo: source, compressionMethod: .none)
        }
        
        let enumerator = fileManager.enumerator(
            at: source,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        let sourceComponents = source.standardizedFileURL.pathComponents
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.hasDirectoryPath { continue }
            let fileComponents = fileURL.standardizedFileURL.pathComponents
            guard fileComponents.count > sourceComponents.count else { continue }
            let relativeComponents = Array(fileComponents[sourceComponents.count...])
            let relativePath = relativeComponents.joined(separator: "/")
            guard !relativePath.isEmpty, relativePath != "mimetype" else { continue }
            try archive.addEntry(with: relativePath, relativeTo: source, compressionMethod: .deflate)
        }
    }
    
    /// 将 Markdown 文本转换为 HTML，使用项目内建的 AST 解析器与渲染器。
    private func convertToHTML(_ markdown: String) -> String {
        var blockParser = MarkdownBlockParser(text: markdown)
        let ast = blockParser.parse()
        return HTMLRenderer.render(ast)
    }
    
    /// 对文本中的 XML 特殊字符进行转义（包含引号）。
    private func escapeXML(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&apos;")
        return result
    }
}

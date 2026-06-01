import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import ZIPFoundation

// MARK: - 导出策略协议

/// 导出策略协议，每种导出格式实现此协议以提供独立的导出逻辑。
protocol ExportStrategy {
    func export(content: String, project: Project, to url: URL) throws
}

// MARK: - Markdown 策略

struct MarkdownExportStrategy: ExportStrategy {
    func export(content: String, project: Project, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - 纯文本策略

struct PlainTextExportStrategy: ExportStrategy {
    func export(content: String, project: Project, to url: URL) throws {
        let plainText = stripMarkdown(content)
        try plainText.write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// 去除 Markdown 标记符号，转换为纯文本。
    func stripMarkdown(_ text: String) -> String {
        let ast = MarkdownParser.parse(text)
        return ast.plainText
    }
}

// MARK: - PDF 策略

struct PDFExportStrategy: ExportStrategy {
    func export(content: String, project: Project, to url: URL) throws {
        #if canImport(AppKit)
        try generatePDFMacOS(content: content, to: url)
        #elseif canImport(UIKit)
        try generatePDFiOS(content: content, to: url)
        #else
        throw ExportError.unsupportedFormat
        #endif
    }
    
    #if canImport(AppKit)
    private func generatePDFMacOS(content: String, to url: URL) throws {
        let plainText = PlainTextExportStrategy().stripMarkdown(content)
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
        let plainText = PlainTextExportStrategy().stripMarkdown(content)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        let attributedString = NSAttributedString(string: plainText, attributes: attributes)
        attributedString.draw(in: textRect)
        
        try pdfData.write(to: url)
    }
    #endif
}

// MARK: - EPUB 策略

struct EPUBExportStrategy: ExportStrategy {
    func export(content: String, project: Project, to url: URL) throws {
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
        
        let htmlContent = markdownToHTML(content)
        let chapterHTML = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>\(project.title.escapingXML())</title>
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
        <dc:title>\(project.title.escapingXML())</dc:title>
        <dc:creator>\(project.author.escapingXML())</dc:creator>
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
    
    /// 使用 ZIPFoundation 将临时目录打包为 EPUB 文件。
    private func zipDirectory(_ source: URL, to destination: URL) throws {
        let archive = try Archive(url: destination, accessMode: .create)
        let fileManager = FileManager.default
        
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
    
    /// 复用项目已有的 Markdown → HTML 渲染器。
    private func markdownToHTML(_ markdown: String) -> String {
        let ast = MarkdownParser.parse(markdown)
        return HTMLRenderer.render(ast)
    }
}

// MARK: - 策略工厂

enum ExportStrategyFactory {
    static func strategy(for format: ExportFormat) -> ExportStrategy {
        switch format {
        case .markdown:
            return MarkdownExportStrategy()
        case .plainText:
            return PlainTextExportStrategy()
        case .pdf:
            return PDFExportStrategy()
        case .epub:
            return EPUBExportStrategy()
        }
    }
}

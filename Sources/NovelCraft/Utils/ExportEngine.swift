import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

enum ExportScope {
    case chapter
    case fullProject
}

enum ExportError: Error {
    case failedToCreateFile
    case failedToWrite
    case unsupportedFormat
    case zipFailed
}

struct ExportEngine {
    let project: Project
    let chapter: Chapter?
    
    func export(format: ExportFormat, scope: ExportScope, includeMetadata: Bool) throws -> URL {
        let content = generateContent(scope: scope, includeMetadata: includeMetadata)
        let fileName = generateFileName(format: format, scope: scope)
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        
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
    
    private func generateContent(scope: ExportScope, includeMetadata: Bool) -> String {
        var parts: [String] = []
        
        if includeMetadata {
            parts.append("# \(project.title)")
            if !project.author.isEmpty {
                parts.append("**作者**: \(project.author)")
            }
            if !project.summary.isEmpty {
                parts.append("**简介**: \(project.summary)")
            }
            parts.append("")
            parts.append("---")
            parts.append("")
        }
        
        switch scope {
        case .chapter:
            if let chapter = chapter {
                parts.append("## \(chapter.title)")
                parts.append(chapter.content)
            }
        case .fullProject:
            let volumes = (project.volumes ?? []).sorted { $0.order < $1.order }
            for volume in volumes {
                parts.append("# \(volume.title)")
                parts.append("")
                let chapters = (volume.chapters ?? []).sorted { $0.order < $1.order }
                for chapter in chapters {
                    parts.append("## \(chapter.title)")
                    parts.append(chapter.content)
                    parts.append("")
                }
            }
        }
        
        return parts.joined(separator: "\n")
    }
    
    private func generateFileName(format: ExportFormat, scope: ExportScope) -> String {
        let baseName: String
        switch scope {
        case .chapter:
            baseName = chapter?.title ?? "chapter"
        case .fullProject:
            baseName = project.title
        }
        let sanitized = baseName.replacingOccurrences(of: "/", with: "-")
        return "\(sanitized).\(format.fileExtension)"
    }
    
    private func stripMarkdown(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "# ", with: "")
        result = result.replacingOccurrences(of: "## ", with: "")
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "*", with: "")
        result = result.replacingOccurrences(of: "```", with: "")
        result = result.replacingOccurrences(of: "> ", with: "")
        result = result.replacingOccurrences(of: "- ", with: "• ")
        result = result.replacingOccurrences(of: "---", with: "")
        return result
    }
    
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
    private func generatePDFiOS(content: String, to url: URL) throws {
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: 612, height: 792), nil)
        
        guard UIGraphicsGetCurrentContext() != nil else {
            throw ExportError.failedToCreateFile
        }
        
        UIGraphicsBeginPDFPage()
        
        let textRect = CGRect(x: 72, y: 72, width: 468, height: 648)
        let plainText = stripMarkdown(content)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        let attributedString = NSAttributedString(string: plainText, attributes: attributes)
        attributedString.draw(in: textRect)
        
        UIGraphicsEndPDFContext()
        try pdfData.write(to: url)
    }
    #endif
    
    private func generateEPUB(content: String, to url: URL, includeMetadata: Bool) throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
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
    <title>\(escapeXML(project.title))</title>
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
        <dc:title>\(escapeXML(project.title))</dc:title>
        <dc:creator>\(escapeXML(project.author))</dc:creator>
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
        try fileManager.removeItem(at: tempDir)
    }
    
    private func zipDirectory(_ source: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", destination.path, "."]
        process.currentDirectoryURL = source
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw ExportError.zipFailed
        }
    }
    
    private func convertToHTML(_ markdown: String) -> String {
        var html = escapeHTML(markdown)
        
        let headingPattern = try! NSRegularExpression(pattern: "^(#{1,6})\\s+(.+)$", options: .anchorsMatchLines)
        let headingMatches = headingPattern.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
        for match in headingMatches.reversed() {
            let level = (html as NSString).substring(with: match.range(at: 1)).count
            let text = (html as NSString).substring(with: match.range(at: 2))
            let replacement = "<h\(level)>\(text)</h\(level)>"
            html = (html as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)
        html = html.replacingOccurrences(of: "```\\n(.+?)\\n```", with: "<pre><code>$1</code></pre>", options: .regularExpression)
        html = html.replacingOccurrences(of: "^>\\s+(.+)$", with: "<blockquote>$1</blockquote>", options: .regularExpression)
        html = html.replacingOccurrences(of: "^\\-\\s+(.+)$", with: "<li>$1</li>", options: .regularExpression)
        
        let paragraphs = html.split(separator: "\n\n", omittingEmptySubsequences: false)
        html = paragraphs.map { para in
            let trimmed = para.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "<p></p>" }
            if trimmed.hasPrefix("<h") || trimmed.hasPrefix("<blockquote>") || trimmed.hasPrefix("<pre>") || trimmed.hasPrefix("<li>") {
                return String(trimmed)
            }
            return "<p>\(trimmed)</p>"
        }.joined(separator: "\n")
        
        return html
    }
    
    private func escapeHTML(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        return result
    }
    
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

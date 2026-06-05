import SwiftUI

/// 文本替换命令，用于从外部触发编辑器内的选区文本替换。
struct TextReplaceCommand: Equatable {
    let range: NSRange
    let replacement: String
}

// MARK: - 跨平台高亮辅助

#if os(macOS)
import AppKit
private typealias PlatformFont = NSFont
private typealias PlatformColor = NSColor
private extension PlatformColor {
    static var labelColorAlias: PlatformColor { .labelColor }
    static var secondaryLabelAlias: PlatformColor { .secondaryLabelColor }
    static var tertiaryLabelAlias: PlatformColor { .tertiaryLabelColor }
}
private extension NSFont {
    static func italicSystemFont(ofSize size: CGFloat) -> NSFont {
        let font = NSFont.systemFont(ofSize: size)
        return NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
    }
}
#else
import UIKit
private typealias PlatformFont = UIFont
private typealias PlatformColor = UIColor
private extension PlatformColor {
    static var labelColorAlias: PlatformColor { .label }
    static var secondaryLabelAlias: PlatformColor { .secondaryLabel }
    static var tertiaryLabelAlias: PlatformColor { .tertiaryLabel }
}
#endif

// MARK: - Markdown 实时语法高亮

/// 对 NSTextStorage 实时应用 Markdown 语法样式，实现原处渲染效果。
enum MarkdownSyntaxHighlighter {

    static func apply(to textStorage: NSTextStorage, fontSize: CGFloat) {
        guard textStorage.length > 0 else { return }
        let text = textStorage.string
        let fullRange = NSRange(location: 0, length: text.utf16.count)

        // 1. 清除旧样式
        textStorage.removeAttribute(.foregroundColor, range: fullRange)
        textStorage.removeAttribute(.font, range: fullRange)
        textStorage.removeAttribute(.backgroundColor, range: fullRange)
        textStorage.removeAttribute(.strikethroughStyle, range: fullRange)
        textStorage.removeAttribute(.underlineStyle, range: fullRange)

        // 2. 应用默认基础样式
        let baseFont = PlatformFont.systemFont(ofSize: fontSize)
        textStorage.addAttribute(.font, value: baseFont, range: fullRange)
        textStorage.addAttribute(.foregroundColor, value: PlatformColor.labelColorAlias, range: fullRange)

        // 3. 各语法高亮
        highlightHeaders(textStorage, text: text, fontSize: fontSize)
        highlightBold(textStorage, text: text, fontSize: fontSize)
        highlightItalic(textStorage, text: text, fontSize: fontSize)
        highlightStrikethrough(textStorage, text: text, fontSize: fontSize)
        highlightInlineCode(textStorage, text: text, fontSize: fontSize)
        highlightLinks(textStorage, text: text, fontSize: fontSize)
        highlightBlockquotes(textStorage, text: text, fontSize: fontSize)
        highlightCodeBlocks(textStorage, text: text, fontSize: fontSize)
        highlightHorizontalRules(textStorage, text: text)
    }

    // MARK: 标题
    private static func highlightHeaders(_ textStorage: NSTextStorage, text: String, fontSize: CGFloat) {
        let pattern = "^(#{1,6})\\s+(.*)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return }
        let nsText = text as NSString

        for match in regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
            let hashRange = match.range(at: 1)
            let contentRange = match.range(at: 2)

            textStorage.addAttribute(.foregroundColor, value: PlatformColor.tertiaryLabelAlias, range: hashRange)

            let level = min(max(nsText.substring(with: hashRange).count, 1), 6)
            let scale: CGFloat = [1.5, 1.3, 1.15, 1.1, 1.05, 1.0][level - 1]
            let headerFont = PlatformFont.boldSystemFont(ofSize: fontSize * scale)
            textStorage.addAttribute(.font, value: headerFont, range: contentRange)
        }
    }

    // MARK: 粗体 **...**
    private static func highlightBold(_ textStorage: NSTextStorage, text: String, fontSize: CGFloat) {
        let pattern = "\\*\\*(.+?)\\*\\*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let nsText = text as NSString

        for match in regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
            let contentRange = match.range(at: 1)
            let boldFont = PlatformFont.boldSystemFont(ofSize: fontSize)
            textStorage.addAttribute(.font, value: boldFont, range: contentRange)

            // ** 标记变灰
            let markerLen = 2
            let startMarker = NSRange(location: match.range.location, length: markerLen)
            let endMarker = NSRange(location: match.range.location + match.range.length - markerLen, length: markerLen)
            textStorage.addAttribute(.foregroundColor, value: PlatformColor.tertiaryLabelAlias, range: startMarker)
            textStorage.addAttribute(.foregroundColor, value: PlatformColor.tertiaryLabelAlias, range: endMarker)
        }
    }

    // MARK: 斜体 *...* 或 _..._
    private static func highlightItalic(_ textStorage: NSTextStorage, text: String, fontSize: CGFloat) {
        // 先处理 *...*（排除 ** 粗体）
        let pattern1 = "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)"
        guard let regex1 = try? NSRegularExpression(pattern: pattern1) else { return }
        let nsText = text as NSString

        for match in regex1.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
            let contentRange = match.range(at: 1)
            let italicFont = PlatformFont.italicSystemFont(ofSize: fontSize)
            textStorage.addAttribute(.font, value: italicFont, range: contentRange)

            let startMarker = NSRange(location: match.range.location, length: 1)
            let endMarker = NSRange(location: match.range.location + match.range.length - 1, length: 1)
            textStorage.addAttribute(.foregroundColor, value: PlatformColor.tertiaryLabelAlias, range: startMarker)
            textStorage.addAttribute(.foregroundColor, value: PlatformColor.tertiaryLabelAlias, range: endMarker)
        }

        // 再处理 _..._（排除 __ 粗体）
        let pattern2 = "(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"
        guard let regex2 = try? NSRegularExpression(pattern: pattern2) else { return }
        for match in regex2.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
            let contentRange = match.range(at: 1)
            let italicFont = PlatformFont.italicSystemFont(ofSize: fontSize)
            textStorage.addAttribute(.font, value: italicFont, range: contentRange)

            let startMarker = NSRange(location: match.range.location, length: 1)
            let endMarker = NSRange(location: match.range.location + match.range.length - 1, length: 1)
            textStorage.addAttribute(.foregroundColor, value: PlatformColor.tertiaryLabelAlias, range: startMarker)
            textStorage.addAttribute(.foregroundColor, value: PlatformColor.tertiaryLabelAlias, range: endMarker)
        }
    }

    // MARK: 删除线 ~~...~~
    private static func highlightStrikethrough(_ textStorage: NSTextStorage, text: String, fontSize: CGFloat) {
        let pattern = "~~(.+?)~~"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let nsText = text as NSString

        for match in regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
            let contentRange = match.range(at: 1)
            textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
            textStorage.addAttribute(.foregroundColor, value: PlatformColor.secondaryLabelAlias, range: contentRange)

            let startMarker = NSRange(location: match.range.location, length: 2)
            let endMarker = NSRange(location: match.range.location + match.range.length - 2, length: 2)
            textStorage.addAttribute(.foregroundColor, value: PlatformColor.tertiaryLabelAlias, range: startMarker)
            textStorage.addAttribute(.foregroundColor, value: PlatformColor.tertiaryLabelAlias, range: endMarker)
        }
    }

    // MARK: 行内代码 `...`
    private static func highlightInlineCode(_ textStorage: NSTextStorage, text: String, fontSize: CGFloat) {
        let pattern = "`([^`]+?)`"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let nsText = text as NSString

        for match in regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
            let fullMatchRange = match.range

            let codeFont = PlatformFont.monospacedSystemFont(ofSize: fontSize * 0.9, weight: .regular)
            textStorage.addAttribute(.font, value: codeFont, range: fullMatchRange)
            textStorage.addAttribute(.foregroundColor, value: PlatformColor.secondaryLabelAlias, range: fullMatchRange)
            #if os(macOS)
            textStorage.addAttribute(.backgroundColor, value: NSColor.secondaryLabelColor.withAlphaComponent(0.08), range: fullMatchRange)
            #else
            textStorage.addAttribute(.backgroundColor, value: UIColor.secondaryLabel.withAlphaComponent(0.08), range: fullMatchRange)
            #endif

            // 反引号本身变灰
            let startBacktick = NSRange(location: match.range.location, length: 1)
            let endBacktick = NSRange(location: match.range.location + match.range.length - 1, length: 1)
            textStorage.addAttribute(.foregroundColor, value: PlatformColor.tertiaryLabelAlias, range: startBacktick)
            textStorage.addAttribute(.foregroundColor, value: PlatformColor.tertiaryLabelAlias, range: endBacktick)
        }
    }

    // MARK: 链接 [text](url)
    private static func highlightLinks(_ textStorage: NSTextStorage, text: String, fontSize: CGFloat) {
        let pattern = #"\[([^\]]+)\]\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let nsText = text as NSString

        for match in regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
            let textRange = match.range(at: 1)
            let urlRange = match.range(at: 2)

            // 链接文本变蓝色
            #if os(macOS)
            textStorage.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: textRange)
            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: textRange)
            #else
            textStorage.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: textRange)
            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: textRange)
            #endif

            // []() 标记变灰
            let bracketOpen = NSRange(location: match.range.location, length: 1)
            let bracketClose = NSRange(location: textRange.location + textRange.length, length: 1)
            let parenOpen = NSRange(location: bracketClose.location + bracketClose.length, length: 1)
            let parenClose = NSRange(location: urlRange.location + urlRange.length, length: 1)
            [bracketOpen, bracketClose, parenOpen, parenClose].forEach { r in
                textStorage.addAttribute(.foregroundColor, value: PlatformColor.tertiaryLabelAlias, range: r)
            }
        }
    }

    // MARK: 引用块 > ...
    private static func highlightBlockquotes(_ textStorage: NSTextStorage, text: String, fontSize: CGFloat) {
        let pattern = "^(>\\s?)(.*)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return }
        let nsText = text as NSString

        for match in regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
            let markerRange = match.range(at: 1)
            let contentRange = match.range(at: 2)

            textStorage.addAttribute(.foregroundColor, value: PlatformColor.tertiaryLabelAlias, range: markerRange)
            textStorage.addAttribute(.foregroundColor, value: PlatformColor.secondaryLabelAlias, range: contentRange)
        }
    }

    // MARK: 代码块 ```...```
    private static func highlightCodeBlocks(_ textStorage: NSTextStorage, text: String, fontSize: CGFloat) {
        let pattern = "^```.*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return }
        let nsText = text as NSString

        for match in regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
            textStorage.addAttribute(.foregroundColor, value: PlatformColor.tertiaryLabelAlias, range: match.range)
        }
    }

    // MARK: 分割线 ---
    private static func highlightHorizontalRules(_ textStorage: NSTextStorage, text: String) {
        let pattern = "^(---|\\*\\*\\*|___)\\s*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return }
        let nsText = text as NSString

        for match in regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
            textStorage.addAttribute(.foregroundColor, value: PlatformColor.tertiaryLabelAlias, range: match.range)
        }
    }
}

// MARK: - macOS

#if os(macOS)
import AppKit

/// 基于 NSTextView 的智能文本编辑器，支持选区检测、光标位置感知与实时 Markdown 语法高亮。
struct SmartTextEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var lineSpacing: CGFloat
    @Binding var replaceCommand: TextReplaceCommand?

    /// 选区变化回调：(是否有选中文字, 选区范围, 光标是否在文本末尾)
    var onSelectionChange: ((Bool, NSRange, Bool) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.string = text
        textView.delegate = context.coordinator
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        // 设置行间距
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes[.paragraphStyle] = paragraphStyle

        // 监听选区变化
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )

        scrollView.documentView = textView
        context.coordinator.textViewRef = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        // 同步文本（避免在编辑时覆盖用户输入）
        if textView.string != text && !context.coordinator.isProgrammaticUpdate {
            let selected = textView.selectedRange()
            textView.string = text
            let maxLoc = textView.string.utf16.count
            let restored = NSRange(location: min(selected.location, maxLoc), length: 0)
            textView.setSelectedRange(restored)
        }

        // 同步字体
        textView.font = NSFont.systemFont(ofSize: fontSize)

        // 同步行间距
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        textView.defaultParagraphStyle = paragraphStyle
        var attrs = textView.typingAttributes
        attrs[.paragraphStyle] = paragraphStyle
        textView.typingAttributes = attrs

        // 处理外部替换命令
        if let cmd = replaceCommand {
            let nsString = textView.string as NSString
            let safeLoc = min(cmd.range.location, nsString.length)
            let safeLen = min(cmd.range.length, nsString.length - safeLoc)
            let safeRange = NSRange(location: safeLoc, length: safeLen)

            context.coordinator.isProgrammaticUpdate = true
            textView.insertText(cmd.replacement, replacementRange: safeRange)
            context.coordinator.isProgrammaticUpdate = false

            // 更新绑定文本
            DispatchQueue.main.async {
                self.text = textView.string
                self.replaceCommand = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SmartTextEditor
        weak var textViewRef: NSTextView?
        var isProgrammaticUpdate = false
        var highlightTask: Task<Void, Never>?

        init(_ parent: SmartTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isProgrammaticUpdate,
                  let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            scheduleHighlight(textView)
        }

        @objc func selectionChanged(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            let hasSelection = range.length > 0
            let isAtEnd = range.location >= textView.string.utf16.count
            parent.onSelectionChange?(hasSelection, range, isAtEnd)
        }

        private func scheduleHighlight(_ textView: NSTextView) {
            highlightTask?.cancel()
            highlightTask = Task {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard !self.isProgrammaticUpdate else { return }
                    MarkdownSyntaxHighlighter.apply(to: textView.textStorage!, fontSize: self.parent.fontSize)
                }
            }
        }
    }
}

#else

// MARK: - iOS

import UIKit

struct SmartTextEditor: UIViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var lineSpacing: CGFloat
    @Binding var replaceCommand: TextReplaceCommand?

    var onSelectionChange: ((Bool, NSRange, Bool) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.font = UIFont.systemFont(ofSize: fontSize)
        textView.text = text
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.delegate = context.coordinator

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        textView.typingAttributes[.paragraphStyle] = paragraphStyle

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text && !context.coordinator.isProgrammaticUpdate {
            let selected = uiView.selectedRange
            uiView.text = text
            let maxLoc = uiView.text.utf16.count
            uiView.selectedRange = NSRange(location: min(selected.location, maxLoc), length: 0)
        }
        uiView.font = UIFont.systemFont(ofSize: fontSize)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        uiView.typingAttributes[.paragraphStyle] = paragraphStyle

        if let cmd = replaceCommand {
            let nsString = uiView.text as NSString
            let safeLoc = min(cmd.range.location, nsString.length)
            let safeLen = min(cmd.range.length, nsString.length - safeLoc)
            let safeRange = NSRange(location: safeLoc, length: safeLen)

            context.coordinator.isProgrammaticUpdate = true
            uiView.replace(safeRange, withText: cmd.replacement)
            context.coordinator.isProgrammaticUpdate = false

            DispatchQueue.main.async {
                self.text = uiView.text
                self.replaceCommand = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SmartTextEditor
        var isProgrammaticUpdate = false
        var highlightTask: Task<Void, Never>?

        init(_ parent: SmartTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isProgrammaticUpdate else { return }
            parent.text = textView.text
            scheduleHighlight(textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            let range = textView.selectedRange
            let hasSelection = range.length > 0
            let isAtEnd = range.location >= textView.text.utf16.count
            parent.onSelectionChange?(hasSelection, range, isAtEnd)
        }

        private func scheduleHighlight(_ textView: UITextView) {
            highlightTask?.cancel()
            highlightTask = Task {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard !self.isProgrammaticUpdate else { return }
                    MarkdownSyntaxHighlighter.apply(to: textView.textStorage, fontSize: self.parent.fontSize)
                }
            }
        }
    }
}
#endif

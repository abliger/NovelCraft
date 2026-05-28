import SwiftUI
import SwiftData

struct EditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    let project: Project
    @Bindable var chapter: Chapter
    
    @State private var editorText: String = ""
    @State private var isPreviewMode = false
    @State private var showFindBar = false
    @State private var findText = ""
    @State private var replaceText = ""
    @State private var fontSize: CGFloat = 16
    @State private var isAutoSaveEnabled = true
    @State private var wordCountUpdate = UUID()
    @State private var showingExportSheet = false
    
    private var isMarkdown: Bool {
        true
    }
    
    var body: some View {
        VStack(spacing: 0) {
            editorToolbar
            
            Divider()
            
            ZStack {
                if isPreviewMode {
                    MarkdownPreview(text: editorText)
                } else {
                    TextEditor(text: $editorText)
                        .font(.system(size: fontSize))
                        .lineSpacing(8)
                        .padding(.horizontal)
                        .scrollContentBackground(.hidden)
                        .background(Color(.textBackgroundColor))
                }
            }
            
            Divider()
            
            statusBar
        }
        .onAppear {
            editorText = chapter.content
        }
        .onChange(of: editorText) { _, newValue in
            chapter.content = newValue
            chapter.updatedAt = Date()
            wordCountUpdate = UUID()
            if isAutoSaveEnabled {
                try? modelContext.save()
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportView(project: project, chapter: chapter)
        }
    }
    
    private var editorToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    applyMarkdown(prefix: "# ")
                } label: {
                    Image(systemName: "textformat.size")
                }
                .help("标题")
                
                Button {
                    applyMarkdown(prefix: "**", suffix: "**")
                } label: {
                    Image(systemName: "bold")
                }
                .help("粗体")
                
                Button {
                    applyMarkdown(prefix: "*", suffix: "*")
                } label: {
                    Image(systemName: "italic")
                }
                .help("斜体")
                
                Divider()
                    .frame(height: 20)
                
                Button {
                    applyMarkdown(prefix: "> ")
                } label: {
                    Image(systemName: "text.quote")
                }
                .help("引用")
                
                Button {
                    applyMarkdown(prefix: "- ")
                } label: {
                    Image(systemName: "list.bullet")
                }
                .help("列表")
                
                Button {
                    applyMarkdown(prefix: "```\n", suffix: "\n```")
                } label: {
                    Image(systemName: "curlybraces")
                }
                .help("代码块")
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    showFindBar.toggle()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .help("查找替换")
                
                Button {
                    isPreviewMode.toggle()
                } label: {
                    Image(systemName: isPreviewMode ? "pencil" : "eye")
                }
                .help(isPreviewMode ? "编辑" : "预览")
                
                Divider()
                    .frame(height: 20)
                
                Button {
                    fontSize = max(12, fontSize - 1)
                } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                .help("缩小字体")
                
                Text("\(Int(fontSize))")
                    .font(.caption)
                    .frame(width: 24)
                
                Button {
                    fontSize = min(32, fontSize + 1)
                } label: {
                    Image(systemName: "textformat.size.larger")
                }
                .help("放大字体")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
    
    private var statusBar: some View {
        HStack(spacing: 16) {
            if showFindBar {
                HStack(spacing: 8) {
                    TextField("查找", text: $findText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                    TextField("替换", text: $replaceText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                    Button("替换") {
                        replace()
                    }
                    Button("全部替换") {
                        replaceAll()
                    }
                    Button {
                        showFindBar = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Label("\(chapter.wordCount) 字", systemImage: "textformat")
                    .font(.caption)
                
                Text(chapter.chapterStatus.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundStyle(statusColor)
                    .cornerRadius(4)
                
                if isAutoSaveEnabled {
                    Label("已保存", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
    
    private var statusColor: Color {
        switch chapter.chapterStatus {
        case .draft: return .gray
        case .revising: return .orange
        case .completed: return .green
        case .archived: return .blue
        }
    }
    
    private func applyMarkdown(prefix: String, suffix: String = "") {
        editorText = prefix + editorText + suffix
    }
    
    private func replace() {
        if let range = editorText.range(of: findText) {
            editorText.replaceSubrange(range, with: replaceText)
        }
    }
    
    private func replaceAll() {
        editorText = editorText.replacingOccurrences(of: findText, with: replaceText)
    }
}

struct MarkdownPreview: View {
    let text: String
    
    var body: some View {
        ScrollView {
            Text(attributedString)
                .padding()
        }
    }
    
    private var attributedString: AttributedString {
        var result = AttributedString(text)
        
        let headingPattern = try! NSRegularExpression(pattern: "^#{1,6}\\s+(.+)$", options: .anchorsMatchLines)
        let headingMatches = headingPattern.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        for match in headingMatches {
            if let range = Range(match.range, in: result) {
                result[range].font = .title
                result[range].foregroundColor = .primary
            }
        }
        
        let boldPattern = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: [])
        let boldMatches = boldPattern.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        for match in boldMatches {
            if let range = Range(match.range(at: 1), in: result) {
                result[range].font = (result[range].font ?? .body).bold()
            }
        }
        
        let italicPattern = try! NSRegularExpression(pattern: "\\*(.+?)\\*", options: [])
        let italicMatches = italicPattern.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        for match in italicMatches {
            if let range = Range(match.range(at: 1), in: result) {
                result[range].font = (result[range].font ?? .body).italic()
            }
        }
        
        return result
    }
}

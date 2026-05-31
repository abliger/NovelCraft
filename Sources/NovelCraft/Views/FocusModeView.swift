import SwiftUI

/// 全屏专注写作模式视图，隐藏无关界面元素，提供计时器与字数统计浮层。
struct FocusModeView: View {
    @Environment(\.modelContext) private var modelContext
    
    let project: Project
    @Bindable var chapter: Chapter
    @Binding var isFocusMode: Bool
    
    /// 编辑器中的文本内容
    @State private var editorText: String = ""
    /// 是否显示统计浮层
    @State private var showStats = false
    /// 是否显示计时器
    @State private var showTimer = false
    /// 计时器已运行秒数
    @State private var timerSeconds = 0
    /// 计时器是否正在运行
    @State private var isTimerRunning = false
    /// 当前字数目标
    @State private var wordGoal = 0
    /// 编辑器字体大小
    @AppStorage("editorFontSize") private var editorFontSize: Double = 16
    /// 编辑区域最大行宽
    @State private var lineWidth: CGFloat = 700
    /// 自动保存任务（用于 debounce）
    @State private var saveTask: Task<Void, Never>?
    /// 固定计时器发布者，避免每次 body 评估都创建新实例
    private let timerPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    /// 当前字体大小
    private var fontSize: CGFloat {
        CGFloat(editorFontSize)
    }
    
    var body: some View {
        ZStack {
            #if os(macOS)
            Color(.textBackgroundColor)
                .ignoresSafeArea()
            #else
            Color(.systemBackground)
                .ignoresSafeArea()
            #endif
            
            VStack(spacing: 0) {
                HStack {
                    Button {
                        withAnimation {
                            isFocusMode = false
                        }
                    } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                        Text("退出专注")
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    
                    Spacer()
                    
                    if showTimer {
                        Text(formatTime(timerSeconds))
                            .font(.system(.title3, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    
                    if showStats {
                        HStack(spacing: 16) {
                            StatBadge(icon: "textformat", value: "\(chapter.wordCount)", label: "字数")
                            StatBadge(icon: "number", value: "\(chapter.characterCount)", label: "字符")
                            if wordGoal > 0 {
                                let remaining = max(0, wordGoal - chapter.wordCount)
                                StatBadge(icon: "target", value: "\(remaining)", label: "剩余")
                            }
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button {
                            showTimer.toggle()
                            if showTimer && !isTimerRunning {
                                isTimerRunning = true
                            }
                        } label: {
                            Image(systemName: showTimer ? "timer" : "timer.slash")
                        }
                        .help("计时器")
                        
                        Button {
                            showStats.toggle()
                        } label: {
                            Image(systemName: showStats ? "chart.bar.fill" : "chart.bar")
                        }
                        .help("统计")
                        
                        Button {
                            editorFontSize = max(12, editorFontSize - 1)
                        } label: {
                            Image(systemName: "textformat.size.smaller")
                        }
                        
                        Button {
                            editorFontSize = min(32, editorFontSize + 1)
                        } label: {
                            Image(systemName: "textformat.size.larger")
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                
                TextEditor(text: $editorText)
                    .font(.system(size: fontSize))
                    .lineSpacing(10)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(maxWidth: lineWidth, minHeight: 600)
                    .padding(.top, 40)
                    .padding(.bottom, 100)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            editorText = chapter.content
            wordGoal = project.dailyWordGoal
        }
        .onChange(of: chapter.id) { _, _ in
            editorText = chapter.content
        }
        .onChange(of: editorText) { _, newValue in
            chapter.content = newValue
            debouncedSave()
        }
        .onChange(of: showTimer) { _, showing in
            if !showing {
                isTimerRunning = false
            }
        }
        .onDisappear {
            saveTask?.cancel()
            try? modelContext.save()
        }
        .onReceive(timerPublisher) { _ in
            if isTimerRunning {
                timerSeconds += 1
            }
        }
    }
    
    /// 延迟保存，避免每次按键都触发数据库写入
    private func debouncedSave() {
        saveTask?.cancel()
        let capturedChapterID = chapter.id
        let capturedText = editorText
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            // 防竞态：若章节已切换则跳过
            guard chapter.id == capturedChapterID else { return }
            // 同步块引用记录（与 EditorView 保持一致）
            BlockRefEngine.syncRefs(sourceBlockID: capturedChapterID, content: capturedText, context: modelContext)
            try? modelContext.save()
        }
    }
    
    /// 将秒数格式化为 "H:MM:SS" 或 "MM:SS"
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

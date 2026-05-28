import SwiftUI

struct FocusModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    let project: Project
    @Bindable var chapter: Chapter
    @Binding var isFocusMode: Bool
    
    @State private var editorText: String = ""
    @State private var showStats = false
    @State private var showTimer = false
    @State private var timerSeconds = 0
    @State private var isTimerRunning = false
    @State private var timer: Timer? = nil
    @State private var wordGoal = 0
    @State private var fontSize: CGFloat = 18
    @State private var lineWidth: CGFloat = 700
    
    var body: some View {
        ZStack {
            Color(.textBackgroundColor)
                .ignoresSafeArea()
            
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
                    .keyboardShortcut(.escape, modifiers: [])
                    
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
                                startTimer()
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
                            fontSize = max(12, fontSize - 1)
                        } label: {
                            Image(systemName: "textformat.size.smaller")
                        }
                        
                        Button {
                            fontSize = min(32, fontSize + 1)
                        } label: {
                            Image(systemName: "textformat.size.larger")
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                
                ScrollView {
                    TextEditor(text: $editorText)
                        .font(.system(size: fontSize))
                        .lineSpacing(10)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(maxWidth: lineWidth, minHeight: 600)
                        .padding(.top, 40)
                        .padding(.bottom, 100)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            editorText = chapter.content
            wordGoal = project.dailyWordGoal
        }
        .onChange(of: editorText) { _, newValue in
            chapter.content = newValue
            chapter.updatedAt = Date()
            try? modelContext.save()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startTimer() {
        isTimerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [self] _ in
            MainActor.assumeIsolated {
                timerSeconds += 1
            }
        }
    }
    
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

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}

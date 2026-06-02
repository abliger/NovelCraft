import SwiftUI

#if os(macOS)

/// 倒计时面板视图，支持同时管理多个倒计时任务。
struct CountdownView: View {
    @StateObject private var engine = CountdownEngine.shared
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if engine.items.isEmpty {
                emptyState
            } else {
                countdownList
            }
            addButtonBar
        }
        .frame(width: 360, height: 460)
        .sheet(isPresented: $showAddSheet) {
            AddCountdownSheet { name, totalSeconds in
                engine.add(name: name, totalSeconds: totalSeconds)
            }
        }
    }

    // MARK: - 子视图

    private var header: some View {
        HStack {
            Image(systemName: "timer")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            Text("倒计时")
                .font(.headline)
                .fontWeight(.bold)
            Spacer()
            if engine.hasFinished {
                Button {
                    engine.clearFinished()
                } label: {
                    Text("清除已完成")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "timer.circle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("暂无倒计时")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("点击下方按钮添加新任务")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var countdownList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(engine.items) { item in
                    CountdownRow(item: item, engine: engine)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var addButtonBar: some View {
        HStack {
            Spacer()
            Button {
                showAddSheet = true
            } label: {
                Label("新建倒计时", systemImage: "plus")
                    .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.windowBackgroundColor).opacity(0.5))
    }
}

// MARK: - 倒计时行

private struct CountdownRow: View {
    let item: CountdownItem
    let engine: CountdownEngine

    var body: some View {
        HStack(spacing: 10) {
            // 进度环
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: item.progress)
                    .stroke(
                        item.isFinished ? Color.red : Color.accentColor,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: item.progress)
            }
            .frame(width: 32, height: 32)

            // 信息
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(statusBadge)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(statusColor.opacity(0.12))
                        .cornerRadius(3)
                }
                Text("\(formatTime(item.remainingSeconds)) / \(item.displayDuration)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 控制按钮
            HStack(spacing: 4) {
                Button {
                    engine.toggle(id: item.id)
                } label: {
                    Image(systemName: item.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(item.isRunning ? Color.orange.opacity(0.12) : Color.accentColor.opacity(0.12))
                        )
                        .foregroundStyle(item.isRunning ? .orange : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(item.isFinished)

                Button {
                    engine.reset(id: item.id)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.secondary.opacity(0.1))
                        )
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(item.isIdle)

                Button {
                    engine.delete(id: item.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.08))
                        )
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.05))
        )
        .opacity(item.isFinished ? 0.6 : 1)
    }

    private var statusBadge: String {
        switch item.state {
        case .idle: return "未开始"
        case .running: return "进行中"
        case .paused: return "已暂停"
        case .finished: return "已完成"
        }
    }

    private var statusColor: Color {
        switch item.state {
        case .idle: return .secondary
        case .running: return .green
        case .paused: return .orange
        case .finished: return .red
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let d = max(0, seconds) / 86400
        let h = (max(0, seconds) % 86400) / 3600
        let m = (max(0, seconds) % 3600) / 60
        let s = max(0, seconds) % 60
        if d >= 1 { return "\(d)天" }
        if h >= 1 { return "\(h)小时\(m)分" }
        if m >= 1 { return "\(m)分\(s)秒" }
        return "\(s)秒"
    }
}

// MARK: - 新建倒计时弹窗

private struct AddCountdownSheet: View {
    let onConfirm: (String, Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var days: Int = 0
    @State private var hours: Int = 0
    @State private var minutes: Int = 25

    private var totalSeconds: Int {
        days * 86400 + hours * 3600 + minutes * 60
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("新建倒计时")
                .font(.headline)

            // 名称
            HStack {
                Text("名称:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
                TextField("例如：交稿截止", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // 时长
            HStack {
                Text("时长:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)

                VStack(spacing: 8) {
                    timeStepper(label: "天", value: $days, range: 0...365)
                    timeStepper(label: "小时", value: $hours, range: 0...23)
                    timeStepper(label: "分钟", value: $minutes, range: 0...59)
                }
            }

            // 快捷预设
            HStack(spacing: 8) {
                PresetButton(label: "番茄钟", days: 0, hours: 0, minutes: 25)
                PresetButton(label: "1小时", days: 0, hours: 1, minutes: 0)
                PresetButton(label: "1天", days: 1, hours: 0, minutes: 0)
                PresetButton(label: "7天", days: 7, hours: 0, minutes: 0)
            }

            Text("总计: \(totalSeconds / 86400)天\((totalSeconds % 86400) / 3600)小时\((totalSeconds % 3600) / 60)分钟")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("取消") { dismiss() }
                    .buttonStyle(.bordered)

                Button("开始倒计时") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    onConfirm(trimmed.isEmpty ? "倒计时" : trimmed, totalSeconds)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(totalSeconds <= 0)
            }
        }
        .padding()
        .frame(width: 340, height: 320)
    }

    private func timeStepper(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
            Stepper("\(value.wrappedValue)", value: value, in: range)
                .frame(width: 120)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func PresetButton(label: String, days: Int, hours: Int, minutes: Int) -> some View {
        Button {
            self.days = days
            self.hours = hours
            self.minutes = minutes
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.08))
                )
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
    }
}

#endif

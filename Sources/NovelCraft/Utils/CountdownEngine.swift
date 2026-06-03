import Foundation
import Combine
#if os(macOS)
import AppKit
#endif

/// 单个倒计时的状态
enum CountdownState: String, Codable {
    case idle
    case running
    case paused
    case finished
}

/// 单个倒计时实例
struct CountdownItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var totalSeconds: Int
    var remainingSeconds: Int
    var state: CountdownState
    var createdAt: Date

    init(id: UUID = UUID(), name: String, totalSeconds: Int) {
        self.id = id
        self.name = name
        self.totalSeconds = totalSeconds
        self.remainingSeconds = totalSeconds
        self.state = .idle
        self.createdAt = Date()
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    var isRunning: Bool { state == .running }
    var isPaused: Bool { state == .paused }
    var isFinished: Bool { state == .finished }
    var isIdle: Bool { state == .idle }

    var displayDuration: String {
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        if days > 0 { return "\(days)天\(hours)小时" }
        if hours > 0 { return "\(hours)小时\(minutes)分" }
        return "\(minutes)分钟"
    }
}

/// 倒计时引擎，管理多个倒计时实例。
///
/// 使用单例模式，通过一个全局 Timer 每秒更新所有运行中的倒计时。
/// 状态通过 `@AppStorage` 持久化，应用重启后自动恢复。
@MainActor
final class CountdownEngine: ObservableObject {
    static let shared = CountdownEngine()

    /// 所有倒计时列表
    @Published var items: [CountdownItem] = []

    private var timerCancellable: AnyCancellable?
    private let timerPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var blinkCancellable: AnyCancellable?

    /// 当前是否有运行中的倒计时
    var hasRunning: Bool { items.contains(where: \.isRunning) }
    /// 最近即将结束的运行中倒计时（用于菜单栏显示）
    var nearestRunning: CountdownItem? {
        items.filter(\.isRunning).min { $0.remainingSeconds < $1.remainingSeconds }
    }
    /// 是否有已结束的倒计时
    var hasFinished: Bool { items.contains(where: \.isFinished) }

    private init() {
        loadItems()
        startGlobalTimer()
    }

    // MARK: - 倒计时管理

    /// 添加并启动一个新的倒计时。
    @discardableResult
    func add(name: String, totalSeconds: Int) -> CountdownItem {
        var item = CountdownItem(name: name, totalSeconds: totalSeconds)
        item.state = .running
        items.append(item)
        saveItems()
        postUpdate()
        return item
    }

    /// 删除指定倒计时。
    func delete(id: UUID) {
        items.removeAll { $0.id == id }
        saveItems()
        postUpdate()
    }

    /// 开始指定倒计时。
    func start(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].state = .running
        saveItems()
        postUpdate()
    }

    /// 暂停指定倒计时。
    func pause(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].state = .paused
        saveItems()
        postUpdate()
    }

    /// 恢复指定倒计时。
    func resume(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].state = .running
        saveItems()
        postUpdate()
    }

    /// 切换指定倒计时的开始/暂停。
    func toggle(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        switch items[index].state {
        case .running:
            items[index].state = .paused
        case .paused, .idle, .finished:
            items[index].state = .running
        }
        saveItems()
        postUpdate()
    }

    /// 重置指定倒计时。
    func reset(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].remainingSeconds = items[index].totalSeconds
        items[index].state = .idle
        saveItems()
        postUpdate()
    }

    /// 清空所有已结束的倒计时。
    func clearFinished() {
        items.removeAll { $0.isFinished }
        saveItems()
        postUpdate()
    }

    // MARK: - 全局计时

    private func startGlobalTimer() {
        stopGlobalTimer()
        timerCancellable = timerPublisher
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.tickAll()
                }
            }
    }

    private func stopGlobalTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func tickAll() {
        var finishedNames: [String] = []
        for index in items.indices where items[index].isRunning {
            items[index].remainingSeconds -= 1
            if items[index].remainingSeconds <= 0 {
                items[index].remainingSeconds = 0
                items[index].state = .finished
                finishedNames.append(items[index].name)
            }
        }
        if !finishedNames.isEmpty {
            saveItems()
            playFinishSound()
            NotificationCenter.default.post(name: .countdownFinished, object: nil)
            postSystemNotification(finishedNames: finishedNames)
        } else if items.contains(where: \.isRunning) {
            // 每隔 10 秒保存一次，避免过于频繁的磁盘写入
            let now = Date().timeIntervalSince1970
            if Int(now) % 10 == 0 {
                saveItems()
            }
        }
        postUpdate()
    }

    // MARK: - 持久化

    func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: countdownItemsKey)
        }
    }

    func loadItems() {
        guard let encoded = UserDefaults.standard.data(forKey: countdownItemsKey),
              let decoded = try? JSONDecoder().decode([CountdownItem].self, from: encoded) else {
            return
        }
        items = decoded
        // 加载时，将已过期的 running 状态改为 finished
        for index in items.indices {
            if items[index].isRunning && items[index].remainingSeconds <= 0 {
                items[index].state = .finished
                items[index].remainingSeconds = 0
            }
        }
    }

    // MARK: - 通知

    private func postUpdate() {
        NotificationCenter.default.post(name: .countdownTick, object: nil)
    }

    private func playFinishSound() {
        #if os(macOS)
        NSSound.beep()
        #endif
    }
    
    private func postSystemNotification(finishedNames: [String]) {
        guard !finishedNames.isEmpty else { return }
        let title = finishedNames.count == 1 ? "倒计时结束" : "\(finishedNames.count) 个倒计时结束"
        let body = finishedNames.joined(separator: "、")
        PluginManager.shared.context.sendNotification(
            title: title,
            body: body,
            identifier: "countdown.finished.\(finishedNames.joined(separator: "."))"
        )
    }
}

private let countdownItemsKey = "com.novelcraft.countdown.items"

// MARK: - 通知名称

extension Notification.Name {
    static let countdownFinished = Notification.Name("NovelCraft.CountdownFinished")
    static let countdownVisibilityChanged = Notification.Name("NovelCraft.CountdownVisibilityChanged")
    static let countdownTick = Notification.Name("NovelCraft.CountdownTick")
}

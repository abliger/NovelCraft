import SwiftUI

#if os(macOS)
import AppKit
import os.log
import Combine

/// 菜单栏控制器，使用 AppKit NSStatusBar 手动管理设备监控、待办清单与倒计时的菜单栏图标。
///
/// 完全绕过 SwiftUI MenuBarExtra 的 isInserted 绑定，避免其在 macOS 上的稳定性问题。
@MainActor
final class MenuBarController: NSObject {
    static let shared = MenuBarController()
    
    private let statusBar = NSStatusBar.system
    
    private var deviceMonitorItem: NSStatusItem?
    private var todoListItem: NSStatusItem?
    private var countdownItem: NSStatusItem?
    
    private var deviceMonitorPopover: NSPopover?
    private var todoListPopover: NSPopover?
    private var countdownPopover: NSPopover?
    
    private var countdownBlinkCancellable: AnyCancellable?
    private var countdownTickObserver: NSObjectProtocol?
    private var countdownFinishObserver: NSObjectProtocol?
    
    private override init() {
        super.init()
        setupObservers()
        syncInitialState()
    }
    
    // MARK: - 通知监听
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceMonitorVisibility(_:)),
            name: .deviceMonitorVisibilityChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTodoListVisibility(_:)),
            name: .todoListVisibilityChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCountdownVisibility(_:)),
            name: .countdownVisibilityChanged,
            object: nil
        )
        countdownTickObserver = NotificationCenter.default.addObserver(
            forName: .countdownTick,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateCountdownIcon()
            }
        }
        countdownFinishObserver = NotificationCenter.default.addObserver(
            forName: .countdownFinished,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.blinkCountdownIcon()
            }
        }
    }
    
    @objc private func handleDeviceMonitorVisibility(_ notification: Notification) {
        guard let isVisible = notification.userInfo?["isVisible"] as? Bool else { return }
        isVisible ? showDeviceMonitor() : hideDeviceMonitor()
    }
    
    @objc private func handleTodoListVisibility(_ notification: Notification) {
        guard let isVisible = notification.userInfo?["isVisible"] as? Bool else { return }
        isVisible ? showTodoList() : hideTodoList()
    }
    
    @objc private func handleCountdownVisibility(_ notification: Notification) {
        guard let isVisible = notification.userInfo?["isVisible"] as? Bool else { return }
        isVisible ? showCountdown() : hideCountdown()
    }
    
    // MARK: - 初始状态同步
    
    private func syncInitialState() {
        let plugins = PluginManager.shared.plugins
        if let plugin = plugins.first(where: { $0.id == "com.novelcraft.plugins.devicemonitor" }) {
            plugin.isEnabled ? showDeviceMonitor() : hideDeviceMonitor()
        }
        if let plugin = plugins.first(where: { $0.id == "com.novelcraft.plugins.todolist" }) {
            plugin.isEnabled ? showTodoList() : hideTodoList()
        }
        if let plugin = plugins.first(where: { $0.id == "com.novelcraft.plugins.countdown" }) {
            plugin.isEnabled ? showCountdown() : hideCountdown()
        }
    }
    
    // MARK: - 设备监控
    
    private func showDeviceMonitor() {
        if let item = deviceMonitorItem {
            item.isVisible = true
            return
        }
        let item = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = nil
        item.isVisible = true
        item.button?.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "设备监控")
        item.button?.target = self
        item.button?.action = #selector(toggleDeviceMonitorPopover)
        deviceMonitorItem = item
    }
    
    private func hideDeviceMonitor() {
        guard let item = deviceMonitorItem else { return }
        closePopover(deviceMonitorPopover)
        item.isVisible = false
    }
    
    @objc private func toggleDeviceMonitorPopover(_ sender: NSStatusBarButton?) {
        guard let button = sender else { return }
        if let popover = deviceMonitorPopover, popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(for: DeviceMonitorView(), on: button, stored: &deviceMonitorPopover)
        }
    }
    
    // MARK: - 待办清单
    
    private func showTodoList() {
        if let item = todoListItem {
            item.isVisible = true
            return
        }
        let item = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = nil
        item.isVisible = true
        item.button?.image = NSImage(systemSymbolName: "star", accessibilityDescription: "待办清单")
        item.button?.target = self
        item.button?.action = #selector(toggleTodoListPopover)
        todoListItem = item
    }
    
    private func hideTodoList() {
        guard let item = todoListItem else { return }
        closePopover(todoListPopover)
        item.isVisible = false
    }
    
    @objc private func toggleTodoListPopover(_ sender: NSStatusBarButton?) {
        guard let button = sender else { return }
        if let popover = todoListPopover, popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(for: TodoListView(), on: button, stored: &todoListPopover)
        }
    }
    
    // MARK: - 倒计时
    
    private func showCountdown() {
        if let item = countdownItem {
            item.isVisible = true
            updateCountdownIcon()
            return
        }
        let item = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = nil
        item.isVisible = true
        item.button?.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "倒计时")
        item.button?.target = self
        item.button?.action = #selector(toggleCountdownPopover)
        countdownItem = item
        updateCountdownIcon()
    }
    
    private func hideCountdown() {
        guard let item = countdownItem else { return }
        closePopover(countdownPopover)
        countdownBlinkCancellable?.cancel()
        countdownBlinkCancellable = nil
        item.isVisible = false
    }
    
    @objc private func toggleCountdownPopover(_ sender: NSStatusBarButton?) {
        guard let button = sender else { return }
        if let popover = countdownPopover, popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(for: CountdownView(), on: button, stored: &countdownPopover)
        }
    }
    
    /// 根据倒计时引擎状态更新菜单栏图标。
    /// 有运行中的倒计时时，显示最快结束项的圆环进度图；无运行中时显示 timer 图标。
    private func updateCountdownIcon() {
        guard let button = countdownItem?.button else { return }
        let engine = CountdownEngine.shared
        
        if engine.hasFinished {
            button.image = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: "倒计时结束")
            button.title = ""
            return
        }
        
        if let nearest = engine.nearestRunning {
            button.image = makeProgressRingImage(progress: nearest.progress, isRunning: true)
            button.title = ""
        } else {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "倒计时")
            button.title = ""
        }
    }
    
    /// 绘制圆环进度图作为菜单栏图标。
    private func makeProgressRingImage(progress: Double, isRunning: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = (size.width / 2) - 2.5
        let trackColor = NSColor.secondaryLabelColor.withAlphaComponent(0.18)
        let progressColor: NSColor = isRunning ? NSColor.controlAccentColor : NSColor.systemRed
        let lineWidth: CGFloat = 2.5
        
        // 轨道
        context.setStrokeColor(trackColor.cgColor)
        context.setLineWidth(lineWidth)
        context.addArc(
            center: center,
            radius: radius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: false
        )
        context.strokePath()
        
        // 进度弧
        context.setStrokeColor(progressColor.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        let endAngle = -.pi / 2 + .pi * 2 * CGFloat(max(0, min(1, progress)))
        context.addArc(
            center: center,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: endAngle,
            clockwise: false
        )
        context.strokePath()
        
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
    
    /// 倒计时结束时图标闪烁。
    private func blinkCountdownIcon() {
        guard let button = countdownItem?.button else { return }
        countdownBlinkCancellable?.cancel()
        
        var blinkCount = 0
        countdownBlinkCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                blinkCount += 1
                if blinkCount % 2 == 1 {
                    button.image = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: "倒计时结束")
                    button.title = ""
                } else {
                    button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "倒计时")
                    button.title = ""
                }
                if blinkCount >= 6 {
                    self.countdownBlinkCancellable?.cancel()
                    self.countdownBlinkCancellable = nil
                    self.updateCountdownIcon()
                }
            }
    }
    
    // MARK: - Popover 辅助
    
    private func showPopover<V: View>(for view: V, on button: NSStatusBarButton, stored popoverRef: inout NSPopover?) {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: view)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popoverRef = popover
    }
    
    private func closePopover(_ popover: NSPopover?) {
        popover?.performClose(nil)
    }
}
#endif

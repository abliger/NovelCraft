import SwiftUI

#if os(macOS)
import AppKit

/// 菜单栏控制器，使用 AppKit NSStatusBar 手动管理设备监控与待办清单的菜单栏图标。
///
/// 完全绕过 SwiftUI MenuBarExtra 的 isInserted 绑定，避免其在 macOS 上的稳定性问题。
@MainActor
final class MenuBarController {
    static let shared = MenuBarController()
    
    private let statusBar = NSStatusBar()
    
    private var deviceMonitorItem: NSStatusItem?
    private var todoListItem: NSStatusItem?
    
    private var deviceMonitorPopover: NSPopover?
    private var todoListPopover: NSPopover?
    
    private var tokens: [any NSObjectProtocol] = []
    
    private init() {
        setupObservers()
        syncInitialState()
    }
    
    // MARK: - 通知监听
    
    private func setupObservers() {
        tokens.append(NotificationCenter.default.addObserver(
            forName: .deviceMonitorVisibilityChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let isVisible = notification.userInfo?["isVisible"] as? Bool else { return }
            isVisible ? self?.showDeviceMonitor() : self?.hideDeviceMonitor()
        })
        
        tokens.append(NotificationCenter.default.addObserver(
            forName: .todoListVisibilityChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let isVisible = notification.userInfo?["isVisible"] as? Bool else { return }
            isVisible ? self?.showTodoList() : self?.hideTodoList()
        })
    }
    
    // MARK: - 初始状态同步
    
    private func syncInitialState() {
        let plugins = PluginManager.shared.plugins
        if let plugin = plugins.first(where: { $0.id == "com.novelcraft.plugins.devicemonitor" }), plugin.isEnabled {
            showDeviceMonitor()
        }
        if let plugin = plugins.first(where: { $0.id == "com.novelcraft.plugins.todolist" }), plugin.isEnabled {
            showTodoList()
        }
    }
    
    // MARK: - 设备监控
    
    private func showDeviceMonitor() {
        guard deviceMonitorItem == nil else { return }
        let item = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "设备监控")
        item.button?.target = self
        item.button?.action = #selector(toggleDeviceMonitorPopover)
        deviceMonitorItem = item
    }
    
    private func hideDeviceMonitor() {
        guard let item = deviceMonitorItem else { return }
        closePopover(deviceMonitorPopover)
        statusBar.removeStatusItem(item)
        deviceMonitorItem = nil
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
        guard todoListItem == nil else { return }
        let item = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "star", accessibilityDescription: "待办清单")
        item.button?.target = self
        item.button?.action = #selector(toggleTodoListPopover)
        todoListItem = item
    }
    
    private func hideTodoList() {
        guard let item = todoListItem else { return }
        closePopover(todoListPopover)
        statusBar.removeStatusItem(item)
        todoListItem = nil
    }
    
    @objc private func toggleTodoListPopover(_ sender: NSStatusBarButton?) {
        guard let button = sender else { return }
        if let popover = todoListPopover, popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(for: TodoListView(), on: button, stored: &todoListPopover)
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

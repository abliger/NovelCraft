import SwiftUI

#if os(macOS)
import AppKit
import os.log

/// 菜单栏控制器，使用 AppKit NSStatusBar 手动管理设备监控与待办清单的菜单栏图标。
///
/// 完全绕过 SwiftUI MenuBarExtra 的 isInserted 绑定，避免其在 macOS 上的稳定性问题。
@MainActor
final class MenuBarController: NSObject {
    static let shared = MenuBarController()
    
    private let statusBar = NSStatusBar.system
    
    private var deviceMonitorItem: NSStatusItem?
    private var todoListItem: NSStatusItem?
    
    private var deviceMonitorPopover: NSPopover?
    private var todoListPopover: NSPopover?
    
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
    }
    
    @objc private func handleDeviceMonitorVisibility(_ notification: Notification) {
        guard let isVisible = notification.userInfo?["isVisible"] as? Bool else { return }
        NSLog("[MenuBar] 设备监控通知: %d", isVisible)
        isVisible ? showDeviceMonitor() : hideDeviceMonitor()
    }
    
    @objc private func handleTodoListVisibility(_ notification: Notification) {
        guard let isVisible = notification.userInfo?["isVisible"] as? Bool else { return }
        NSLog("[MenuBar] 待办清单通知: %d", isVisible)
        isVisible ? showTodoList() : hideTodoList()
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
        guard deviceMonitorItem == nil else {
            NSLog("[MenuBar] 设备监控已存在，跳过创建")
            return
        }
        let item = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = nil
        item.isVisible = true
        item.button?.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "设备监控")
        item.button?.target = self
        item.button?.action = #selector(toggleDeviceMonitorPopover)
        deviceMonitorItem = item
        NSLog("[MenuBar] 设备监控图标已创建")
    }
    
    private func hideDeviceMonitor() {
        guard let item = deviceMonitorItem else { return }
        closePopover(deviceMonitorPopover)
        item.isVisible = false
        statusBar.removeStatusItem(item)
        deviceMonitorItem = nil
        NSLog("[MenuBar] 设备监控图标已移除")
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
        guard todoListItem == nil else {
            NSLog("[MenuBar] 待办清单已存在，跳过创建")
            return
        }
        let item = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = nil
        item.isVisible = true
        item.button?.image = NSImage(systemSymbolName: "star", accessibilityDescription: "待办清单")
        item.button?.target = self
        item.button?.action = #selector(toggleTodoListPopover)
        todoListItem = item
        NSLog("[MenuBar] 待办清单图标已创建")
    }
    
    private func hideTodoList() {
        guard let item = todoListItem else { return }
        closePopover(todoListPopover)
        item.isVisible = false
        statusBar.removeStatusItem(item)
        todoListItem = nil
        NSLog("[MenuBar] 待办清单图标已移除")
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

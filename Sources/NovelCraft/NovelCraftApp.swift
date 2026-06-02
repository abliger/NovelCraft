import SwiftUI
import SwiftData
import CoreData

/// 应用全局通知名称。
extension Notification.Name {
    static let showPluginManager = Notification.Name("NovelCraft.ShowPluginManager")
    static let triggerPluginAction = Notification.Name("NovelCraft.TriggerPluginAction")
}

/// 菜单栏状态管理器，统一控制 MenuBarExtra 的显示与隐藏。
///
/// 使用 `@StateObject` 挂载在 `App` 层级，使 SwiftUI 能正确观察状态变化并重新计算 Scene。
@MainActor
final class MenuBarState: ObservableObject {
    @Published var deviceMonitorVisible = false
    @Published var todoListVisible = false
    
    private var tokens: [any NSObjectProtocol] = []
    
    init() {
        setupObservers()
        syncInitialState()
    }
    
    private func setupObservers() {
        tokens.append(NotificationCenter.default.addObserver(
            forName: .deviceMonitorVisibilityChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let isVisible = notification.userInfo?["isVisible"] as? Bool else { return }
            Task { @MainActor [weak self] in
                self?.deviceMonitorVisible = isVisible
            }
        })
        
        tokens.append(NotificationCenter.default.addObserver(
            forName: .todoListVisibilityChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let isVisible = notification.userInfo?["isVisible"] as? Bool else { return }
            Task { @MainActor [weak self] in
                self?.todoListVisible = isVisible
            }
        })
    }
    
    /// 与 PluginManager 中已注册插件的当前启用状态同步。
    private func syncInitialState() {
        let plugins = PluginManager.shared.plugins
        if let plugin = plugins.first(where: { $0.id == "com.novelcraft.plugins.devicemonitor" }) {
            deviceMonitorVisible = plugin.isEnabled
        }
        if let plugin = plugins.first(where: { $0.id == "com.novelcraft.plugins.todolist" }) {
            todoListVisible = plugin.isEnabled
        }
    }
}

@main
struct NovelCraftApp: App {
    @StateObject private var menuBarState = MenuBarState()
    
    /// 保存通知观察者的 token，用于生命周期管理
    private var notificationTokens: [any NSObjectProtocol] = []
    
    init() {
        setupAutoTimestamps()
        PluginManager.shared.registerBuiltInPlugins()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .applyTheme()
        }
        #if os(macOS)
        .commands {
            PluginMenuCommands()
        }
        #endif
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        
        MenuBarExtra("设备监控", systemImage: "cpu", isInserted: $menuBarState.deviceMonitorVisible) {
            DeviceMonitorView()
        }
        .menuBarExtraStyle(.window)
        
        MenuBarExtra("待办清单", systemImage: "star", isInserted: $menuBarState.todoListVisible) {
            TodoListView()
        }
        .menuBarExtraStyle(.window)
        #endif
    }
    
    /// 注册 Core Data 保存前通知，自动更新所有带 `updatedAt` 字段的模型对象。
    /// 使用 nil queue，直接在发出通知的线程处理，避免主线程调度延迟。
    private mutating func setupAutoTimestamps() {
        let token = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSManagedObjectContextWillSaveNotification"),
            object: nil,
            queue: nil
        ) { notification in
            guard let moc = notification.object as? NSManagedObjectContext else { return }
            // 仅遍历已变更的对象，而非全部 registeredObjects，降低性能开销
            for object in moc.insertedObjects.union(moc.updatedObjects) where !object.isDeleted {
                if object.entity.attributesByName["updatedAt"] != nil {
                    object.setValue(Date(), forKey: "updatedAt")
                }
            }
        }
        notificationTokens.append(token)
    }
}

// MARK: - 插件菜单命令 (macOS)

#if os(macOS)
/// macOS 菜单栏中的「插件」菜单命令。
///
/// 提供插件管理中心入口、常用插件快捷操作，以及恢复内置插件功能。
@MainActor
struct PluginMenuCommands: Commands {
    var body: some Commands {
        CommandMenu("插件") {
            Button("插件管理...") {
                NotificationCenter.default.post(name: .showPluginManager, object: nil)
            }
            .keyboardShortcut("P", modifiers: [.command, .shift])
            
            Divider()
            
            // 常用插件快捷操作
            PluginQuickActionsSection()
            
            Divider()
            
            Button("恢复官方内置插件") {
                PluginManager.shared.resetBuiltInPlugins()
            }
        }
    }
}

/// 插件快捷操作菜单分组。
@MainActor
struct PluginQuickActionsSection: View {
    @StateObject private var pluginManager = PluginManager.shared
    
    var body: some View {
        let enabledPlugins = pluginManager.plugins.filter { $0.isEnabled }
        
        if enabledPlugins.isEmpty {
            Text("暂无已启用插件")
                .font(.caption)
                .foregroundStyle(.secondary)
                .disabled(true)
        } else {
            ForEach(Array(enabledPlugins.enumerated()), id: \.offset) { _, plugin in
                if let contributor = plugin as? any EditorToolbarContributor,
                   let firstItem = contributor.toolbarItems.first {
                    Button(firstItem.tooltip) {
                        firstItem.action()
                    }
                }
            }
        }
    }
}
#endif

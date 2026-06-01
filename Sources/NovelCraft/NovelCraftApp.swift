import SwiftUI
import SwiftData
import CoreData

/// 应用全局通知名称。
extension Notification.Name {
    static let showPluginManager = Notification.Name("NovelCraft.ShowPluginManager")
    static let triggerPluginAction = Notification.Name("NovelCraft.TriggerPluginAction")
}

/// 设备监控菜单栏状态，用于控制 MenuBarExtra 的显示与隐藏。
final class DeviceMonitorState: ObservableObject {
    @Published var isVisible = false
}

/// 待办清单菜单栏状态，用于控制 MenuBarExtra 的显示与隐藏。
final class TodoListState: ObservableObject {
    @Published var isVisible = false
}

@main
struct NovelCraftApp: App {
    private let deviceMonitorState = DeviceMonitorState()
    private let todoListState = TodoListState()
    
    /// 保存通知观察者的 token，用于生命周期管理
    private var notificationTokens: [any NSObjectProtocol] = []
    
    init() {
        setupAutoTimestamps()
        // 必须先注册 MenuBarExtra 通知监听，再注册插件，否则插件 setup 发出的通知会丢失
        setupDeviceMonitorObserver()
        setupTodoListObserver()
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
        
        MenuBarExtra("设备监控", systemImage: "cpu", isInserted: Binding(
            get: { deviceMonitorState.isVisible },
            set: { deviceMonitorState.isVisible = $0 }
        )) {
            DeviceMonitorView()
        }
        .menuBarExtraStyle(.window)
        
        MenuBarExtra("待办清单", systemImage: "star", isInserted: Binding(
            get: { todoListState.isVisible },
            set: { todoListState.isVisible = $0 }
        )) {
            TodoListView()
        }
        .menuBarExtraStyle(.window)
        #endif
    }
    
    /// 监听设备监控插件的可见性变化通知。
    private mutating func setupDeviceMonitorObserver() {
        let token = NotificationCenter.default.addObserver(
            forName: .deviceMonitorVisibilityChanged,
            object: nil,
            queue: .main
        ) { [weak deviceMonitorState] notification in
            guard let isVisible = notification.userInfo?["isVisible"] as? Bool else { return }
            deviceMonitorState?.isVisible = isVisible
        }
        notificationTokens.append(token)
    }
    
    /// 监听待办清单插件的可见性变化通知。
    private mutating func setupTodoListObserver() {
        let token = NotificationCenter.default.addObserver(
            forName: .todoListVisibilityChanged,
            object: nil,
            queue: .main
        ) { [weak todoListState] notification in
            guard let isVisible = notification.userInfo?["isVisible"] as? Bool else { return }
            todoListState?.isVisible = isVisible
        }
        notificationTokens.append(token)
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

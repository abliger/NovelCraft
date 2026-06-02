import SwiftUI
import SwiftData
import CoreData

/// 应用全局通知名称。
extension Notification.Name {
    static let showPluginManager = Notification.Name("NovelCraft.ShowPluginManager")
    static let triggerPluginAction = Notification.Name("NovelCraft.TriggerPluginAction")
}

@main
struct NovelCraftApp: App {
    /// 保存通知观察者的 token，用于生命周期管理
    private var notificationTokens: [any NSObjectProtocol] = []
    
    init() {
        setupAutoTimestamps()
        PluginManager.shared.registerBuiltInPlugins()
        #if os(macOS)
        _ = MenuBarController.shared
        #endif
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

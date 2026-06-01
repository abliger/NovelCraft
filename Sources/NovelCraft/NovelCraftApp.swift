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
        #endif
    }
    
    /// 注册 Core Data 保存前通知，自动更新所有带 `updatedAt` 字段的模型对象。
    private func setupAutoTimestamps() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSManagedObjectContextWillSaveNotification"),
            object: nil,
            queue: .main
        ) { notification in
            guard let moc = notification.object as? NSManagedObjectContext else { return }
            for object in moc.registeredObjects where object.hasChanges && !object.isDeleted {
                if object.entity.attributesByName["updatedAt"] != nil {
                    object.setValue(Date(), forKey: "updatedAt")
                }
            }
        }
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

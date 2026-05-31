import SwiftUI
import SwiftData
import CoreData

@main
struct NovelCraftApp: App {
    init() {
        setupAutoTimestamps()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .applyTheme()
        }
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
            for object in moc.registeredObjects where object.hasChanges {
                if object.entity.attributesByName["updatedAt"] != nil {
                    object.setValue(Date(), forKey: "updatedAt")
                }
            }
        }
    }
}

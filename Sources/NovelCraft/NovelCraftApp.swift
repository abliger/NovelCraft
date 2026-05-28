import SwiftUI
import SwiftData
import CoreData

@main
struct NovelCraftApp: App {
    let container: ModelContainer
    
    init() {
        let schema = Schema([
            Project.self,
            Volume.self,
            Chapter.self,
            StoryScene.self,
            Character.self,
            WorldSetting.self,
            OutlineNode.self,
            Note.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: fallbackConfig)
            print("数据库初始化失败，已降级到内存存储: \(error)")
        }
        
        setupAutoTimestamps()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .applyTheme()
        }
        .modelContainer(container)
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

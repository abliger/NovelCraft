import SwiftUI
import SwiftData

@main
struct NovelCraftApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .applyTheme()
        }
        .modelContainer(for: [
            Project.self,
            Volume.self,
            Chapter.self,
            StoryScene.self,
            Character.self,
            WorldSetting.self,
            OutlineNode.self,
            Note.self,
        ])
    }
}

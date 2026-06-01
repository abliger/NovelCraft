import SwiftData

/// 应用全局的 SwiftData Schema 定义，用于所有项目数据库的创建。
enum AppSchema {
    static let shared = Schema([
        Project.self,
        Volume.self,
        Chapter.self,
        StoryScene.self,
        Character.self,
        WorldSetting.self,
        OutlineNode.self,
        Note.self,
        ContentBlockRef.self,
        SpreadsheetSheet.self,
        SpreadsheetCell.self,
        TodoItem.self,
    ])
}

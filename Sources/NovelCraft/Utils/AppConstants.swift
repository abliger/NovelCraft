import Foundation

/// 应用全局常量配置，集中管理所有硬编码的魔法数字与默认参数。
enum AppConstants {
    
    /// 编辑器相关常量
    enum Editor {
        static let minFontSize: Double = 12
        static let maxFontSize: Double = 32
        static let defaultFontSize: Double = 16
        static let defaultLineSpacing: Double = 8
        static let debounceInterval: TimeInterval = 1.5
        static let fileSyncInterval: TimeInterval = 10
        static let focusModeLineSpacing: Double = 10
        static let focusModeMaxLineWidth: CGFloat = 700
    }
    
    /// 面板与视图尺寸
    enum Layout {
        static let backlinkPanelWidth: CGFloat = 260
        static let rightPanelWidth: CGFloat = 280
        static let blockSearchWidth: CGFloat = 400
        static let blockSearchHeight: CGFloat = 500
        
        enum Sheet {
            static let narrowWidth: CGFloat = 400
            static let narrowHeight: CGFloat = 300
            static let standardWidth: CGFloat = 450
            static let standardHeight: CGFloat = 400
            static let tallHeight: CGFloat = 600
        }
    }
    
    /// 写作目标默认值
    enum WritingGoals {
        static let defaultTargetWordCount: Int = 50000
        static let defaultDailyWordGoal: Int = 2000
        static let targetStep: Int = 5000
        static let dailyStep: Int = 500
    }
    
    /// 自动保存
    enum AutoSave {
        static let defaultInterval: Double = 30
    }
    
    /// 图片处理
    enum Image {
        static let defaultHandlingMode: Int = 1
    }
    
    /// 项目存储
    enum Project {
        static let defaultDirectoryName = "NovelCraftProjects"
        static let databaseFileName = "NovelCraft.store"
        static let coverFileName = "cover.png"
        static let assetsImagesPath = "assets/images"
    }
    
    /// 主题与颜色
    enum Theme {
        static let noteColors: [(name: String, colorName: String)] = [
            ("yellow", "黄色"),
            ("red", "红色"),
            ("green", "绿色"),
            ("blue", "蓝色"),
            ("purple", "紫色"),
            ("orange", "橙色"),
            ("pink", "粉色"),
        ]
        static let defaultNoteColor = "yellow"
    }
}

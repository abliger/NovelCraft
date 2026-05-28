import SwiftUI

/// 应用主题模式枚举，支持跟随系统、浅色与深色三种模式。
enum AppTheme: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2
    
    /// 用户界面中显示的主题名称
    var name: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

/// 主题管理器，负责将 `AppTheme` 转换为 SwiftUI 可用的 `ColorScheme`。
enum ThemeManager {
    /// AppStorage 键名常量
    static let themeModeKey = "themeMode"
    
    static func colorScheme(from theme: AppTheme) -> ColorScheme? {
        switch theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// 主题修改器，读取用户保存在 `AppStorage` 中的主题偏好并应用到视图。
struct ThemeModifier: ViewModifier {
    @AppStorage(ThemeManager.themeModeKey) private var themeMode = 0
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(ThemeManager.colorScheme(from: AppTheme(rawValue: themeMode) ?? .system))
    }
}

extension View {
    /// 为当前视图应用全局主题偏好。
    func applyTheme() -> some View {
        modifier(ThemeModifier())
    }
}

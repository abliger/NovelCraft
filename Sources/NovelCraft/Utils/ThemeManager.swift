import SwiftUI

enum AppTheme: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2
    
    var name: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

struct ThemeManager {
    static func colorScheme(from theme: AppTheme) -> ColorScheme? {
        switch theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct ThemeModifier: ViewModifier {
    @AppStorage("themeMode") private var themeMode = 0
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(ThemeManager.colorScheme(from: AppTheme(rawValue: themeMode) ?? .system))
    }
}

extension View {
    func applyTheme() -> some View {
        modifier(ThemeModifier())
    }
}

import SwiftUI

// MARK: - 平台适配背景色

extension View {
    /// 根据当前平台应用合适的控制背景色。
    func platformBackgroundColor() -> some View {
        #if os(macOS)
        self.background(Color(nsColor: .controlBackgroundColor))
        #else
        self.background(Color(.secondarySystemBackground))
        #endif
    }
    
    /// 根据当前平台应用合适的窗口背景色。
    func platformWindowBackgroundColor() -> some View {
        #if os(macOS)
        self.background(Color(nsColor: .windowBackgroundColor))
        #else
        self.background(Color(.systemBackground))
        #endif
    }
}

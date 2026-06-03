import Foundation
import SwiftUI

/// 设备监控插件。
///
/// 启用后在 macOS 菜单栏中添加设备监控图标，点击后展示 CPU、内存与网络的实时使用情况。
/// 仅支持 macOS。
@MainActor
final class DeviceMonitorPlugin: NovelCraftPlugin {
    let id = "com.novelcraft.plugins.devicemonitor"
    let name = "设备监控"
    let description = "在菜单栏中实时监控 CPU、内存与网络的使用情况。"
    let version = "1.0.0"
    let author = "NovelCraft 官方"
    var isEnabled: Bool = true {
        didSet {
            if oldValue != isEnabled {
                postVisibilityChange(isVisible: isEnabled)
            }
        }
    }
    
    private var context: PluginContext?
    
    func setup(context: PluginContext) {
        self.context = context
        // 插件注册时发送初始状态
        postVisibilityChange(isVisible: isEnabled)
    }
    
    func teardown() {
        postVisibilityChange(isVisible: false)
        context = nil
    }
    
    /// 发送菜单栏可见性变化通知。
    private func postVisibilityChange(isVisible: Bool) {
        NotificationCenter.default.post(
            name: .deviceMonitorVisibilityChanged,
            object: nil,
            userInfo: ["isVisible": isVisible]
        )
    }
}

// MARK: - 通知名称

extension Notification.Name {
    static let deviceMonitorVisibilityChanged = Notification.Name("NovelCraft.DeviceMonitorVisibilityChanged")
}

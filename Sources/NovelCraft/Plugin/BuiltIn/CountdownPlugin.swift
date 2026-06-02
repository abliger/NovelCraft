import Foundation
import SwiftUI

/// 倒计时插件。
///
/// 启用后在 macOS 菜单栏中添加倒计时图标，支持番茄钟与自定义时长的时间管理。
/// 仅支持 macOS。
@MainActor
final class CountdownPlugin: NovelCraftPlugin {
    let id = "com.novelcraft.plugins.countdown"
    let name = "倒计时"
    let description = "在菜单栏中进行番茄钟或自定义时长的倒计时，帮助保持写作专注。"
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
        postVisibilityChange(isVisible: isEnabled)
    }

    func teardown() {
        postVisibilityChange(isVisible: false)
        context = nil
    }

    /// 发送菜单栏可见性变化通知。
    private func postVisibilityChange(isVisible: Bool) {
        NotificationCenter.default.post(
            name: .countdownVisibilityChanged,
            object: nil,
            userInfo: ["isVisible": isVisible]
        )
    }
}

import Foundation
import SwiftUI
import SwiftData

// MARK: - 插件能力标记协议（空协议，仅用于类型约束与组合）

/// 标记该插件可向编辑器工具栏贡献按钮与动作。
@MainActor
protocol EditorToolbarContributor: NovelCraftPlugin {
    /// 该插件贡献的工具栏按钮定义列表。
    var toolbarItems: [PluginToolbarItem] { get }
}

/// 标记该插件可向导出面板贡献新的导出格式或选项。
@MainActor
protocol ExportFormatContributor: NovelCraftPlugin {
    /// 该插件支持的额外导出格式标识。
    var supportedFormats: [PluginExportFormat] { get }
    /// 执行导出，返回生成文件的 URL。
    func export(content: String, format: PluginExportFormat, metadata: PluginExportMetadata) throws -> URL
}

/// 标记该插件可向右侧辅助边栏贡献新的面板标签页。
@MainActor
protocol SidebarPanelContributor: NovelCraftPlugin {
    /// 该插件贡献的面板定义列表。
    var sidebarPanels: [PluginSidebarPanel] { get }
}

/// 标记该插件可在章节内容保存前/后进行文本处理。
@MainActor
protocol ContentProcessor: NovelCraftPlugin {
    /// 处理章节正文，返回处理后的文本。
    /// 调用时机：自动保存前、导出内容组装前。
    func process(content: String, chapter: Chapter) -> String
}

/// 标记该插件可向章节上下文菜单贡献额外动作。
@MainActor
protocol ChapterActionContributor: NovelCraftPlugin {
    /// 该插件贡献的章节动作定义列表。
    var chapterActions: [PluginChapterAction] { get }
}

/// 标记该插件支持自定义配置。
/// PluginSettingsView 会为实现了此协议的插件显示「配置」按钮，点击后弹出配置面板。
@MainActor
protocol PluginConfigurable: NovelCraftPlugin {
    /// 配置面板视图。插件在此视图内管理自己的配置项。
    var configurationView: AnyView { get }
}

// MARK: - 统一配置存储

/// 插件统一配置存储，基于 UserDefaults，提供命名空间隔离。
struct PluginConfigStore {
    /// 生成带插件命名空间的 UserDefaults key。
    private static func namespacedKey(pluginID: String, key: String) -> String {
        "plugin.config.\(pluginID).\(key)"
    }
    
    /// 读取字符串配置值。
    static func string(pluginID: String, key: String) -> String? {
        UserDefaults.standard.string(forKey: namespacedKey(pluginID: pluginID, key: key))
    }
    
    /// 写入字符串配置值。
    static func set(_ value: String, pluginID: String, key: String) {
        UserDefaults.standard.set(value, forKey: namespacedKey(pluginID: pluginID, key: key))
    }
    
    /// 删除指定配置项。
    static func remove(pluginID: String, key: String) {
        UserDefaults.standard.removeObject(forKey: namespacedKey(pluginID: pluginID, key: key))
    }
    
    /// 读取布尔配置值。
    static func bool(pluginID: String, key: String) -> Bool {
        UserDefaults.standard.bool(forKey: namespacedKey(pluginID: pluginID, key: key))
    }
    
    /// 写入布尔配置值。
    static func set(_ value: Bool, pluginID: String, key: String) {
        UserDefaults.standard.set(value, forKey: namespacedKey(pluginID: pluginID, key: key))
    }
    
    /// 读取整数配置值。
    static func integer(pluginID: String, key: String) -> Int {
        UserDefaults.standard.integer(forKey: namespacedKey(pluginID: pluginID, key: key))
    }
    
    /// 写入整数配置值。
    static func set(_ value: Int, pluginID: String, key: String) {
        UserDefaults.standard.set(value, forKey: namespacedKey(pluginID: pluginID, key: key))
    }
    
    /// 读取双精度配置值。
    static func double(pluginID: String, key: String) -> Double {
        UserDefaults.standard.double(forKey: namespacedKey(pluginID: pluginID, key: key))
    }
    
    /// 写入双精度配置值。
    static func set(_ value: Double, pluginID: String, key: String) {
        UserDefaults.standard.set(value, forKey: namespacedKey(pluginID: pluginID, key: key))
    }
}

// MARK: - 核心插件协议

/// NovelCraft 插件接口。所有插件（包括官方内置插件）必须实现此协议。
///
/// 插件通过组合上述「能力标记协议」来声明自己能提供哪些扩展点。
/// PluginManager 在扫描插件时会根据能力协议将插件注册到对应的扩展点中。
@MainActor
protocol NovelCraftPlugin: AnyObject, Identifiable {
    /// 插件唯一标识符（建议 reverse-DNS 格式，如 `com.novelcraft.plugins.wordcount`）
    var id: String { get }
    /// 插件显示名称
    var name: String { get }
    /// 插件简介
    var description: String { get }
    /// 插件版本号（语义化版本，如 `1.0.0`）
    var version: String { get }
    /// 插件作者
    var author: String { get }
    /// 是否启用。PluginManager 仅对启用状态的插件分发事件。
    var isEnabled: Bool { get set }
    
    /// 插件被加载时调用。可在此进行一次性初始化。
    /// - Parameter context: 插件上下文，提供项目数据、数据库访问等内部 API。
    func setup(context: PluginContext)
    
    /// 插件被卸载或应用退出时调用。可在此释放资源、移除监听。
    func teardown()
}

// MARK: - 插件上下文（内部 API，不对外暴露）

/// 插件上下文，封装插件可访问的内部 API。
/// 注意：此 API 仅供官方/内置插件使用，不保证向后兼容。
@MainActor
final class PluginContext: ObservableObject {
    /// 当前打开的项目（nil 表示处于项目列表）
    @Published var currentProject: Project?
    /// 当前选中的章节
    @Published var selectedChapter: Chapter?
    /// 当前项目的数据库上下文（nil 表示未打开项目）
    var modelContext: ModelContext? { projectModelContainer?.mainContext }
    
    /// 内部持有当前项目的数据库容器，不直接暴露给插件。
    private(set) var projectModelContainer: ModelContainer?
    
    /// 更新当前项目与数据库容器。
    func updateProject(_ project: Project?, container: ModelContainer?) {
        self.currentProject = project
        self.projectModelContainer = container
    }
    
    /// 更新当前选中的章节。
    func updateSelectedChapter(_ chapter: Chapter?) {
        self.selectedChapter = chapter
    }
    
    // MARK: 便捷查询 API
    
    /// 获取当前项目的所有卷（按 order 排序）。
    func fetchVolumes() -> [Volume] {
        guard let project = currentProject else { return [] }
        return project.volumes.sorted { $0.order < $1.order }
    }
    
    /// 获取当前项目的所有角色。
    func fetchCharacters() -> [Character] {
        guard let project = currentProject else { return [] }
        return project.characters
    }
    
    /// 获取当前项目的所有世界观设定。
    func fetchWorldSettings() -> [WorldSetting] {
        guard let project = currentProject else { return [] }
        return project.worldSettings
    }
    
    /// 获取当前项目的所有大纲节点。
    func fetchOutlineNodes() -> [OutlineNode] {
        guard let project = currentProject else { return [] }
        return project.outlineNodes
    }
    
    /// 获取指定章节的正文内容。
    func fetchChapterContent(_ chapterID: UUID) -> String? {
        guard let ctx = modelContext else { return nil }
        let descriptor = FetchDescriptor<Chapter>(predicate: #Predicate { $0.id == chapterID })
        return (try? ctx.fetch(descriptor))?.first?.content
    }
    
    /// 保存数据库变更。
    func save() {
        try? modelContext?.save()
    }
}

// MARK: - 插件 UI / 动作定义

/// 插件工具栏按钮定义。
struct PluginToolbarItem {
    /// 唯一标识
    let id: String
    /// 按钮图标（SF Symbol 名称）
    let icon: String
    /// 悬停提示
    let tooltip: String
    /// 点击执行的动作
    let action: @MainActor () -> Void
}

/// 插件导出格式定义。
struct PluginExportFormat: Hashable, Identifiable {
    let id: String
    let displayName: String
    let fileExtension: String
}

/// 插件侧边栏面板定义。
struct PluginSidebarPanel: Identifiable {
    let id: String
    let title: String
    let icon: String
    /// 面板内容视图构建闭包
    let content: @MainActor () -> AnyView
}

/// 插件章节动作定义。
struct PluginChapterAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    /// 执行动作
    let action: @MainActor (Chapter) -> Void
}

/// 插件导出所需的元数据。
struct PluginExportMetadata {
    let projectTitle: String
    let projectAuthor: String
    let projectSummary: String
    let chapterTitle: String?
}

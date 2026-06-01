import Foundation
import SwiftUI
import SwiftData

/// 插件管理器，负责注册、加载、分发事件给所有插件。
///
/// 使用单例模式：`PluginManager.shared`。
/// 官方内置插件在应用启动时通过 `registerBuiltInPlugins()` 自动注册。
@MainActor
final class PluginManager: ObservableObject {
    static let shared = PluginManager()
    
    /// 所有已注册的插件列表。
    @Published var plugins: [NovelCraftPlugin] = []
    
    /// 内置插件 ID 集合（用于标记不可删除的官方插件）。
    private var builtInPluginIDs: Set<String> = []
    
    /// 插件上下文，所有插件共享同一个上下文实例。
    let context = PluginContext()
    
    // MARK: 按能力分类的缓存（提升查找效率）
    
    private var toolbarContributors: [EditorToolbarContributor] = []
    private var exportContributors: [ExportFormatContributor] = []
    private var sidebarContributors: [SidebarPanelContributor] = []
    private var contentProcessors: [ContentProcessor] = []
    private var chapterActionContributors: [ChapterActionContributor] = []
    
    private init() {}
    
    // MARK: 注册与注销
    
    /// 注册一个插件实例。
    /// - Parameter isBuiltIn: 是否为内置插件，内置插件不可删除但可禁用。
    func register(_ plugin: NovelCraftPlugin, isBuiltIn: Bool = false) {
        guard !plugins.contains(where: { $0.id == plugin.id }) else { return }
        plugins.append(plugin)
        if isBuiltIn {
            builtInPluginIDs.insert(plugin.id)
        }
        plugin.setup(context: context)
        classify(plugin)
    }
    
    /// 判断指定插件是否为内置插件。
    func isBuiltIn(pluginID: String) -> Bool {
        builtInPluginIDs.contains(pluginID)
    }
    
    /// 注销一个插件实例。
    func unregister(_ plugin: NovelCraftPlugin) {
        plugin.teardown()
        plugins.removeAll { $0.id == plugin.id }
        unclassify(plugin)
    }
    
    /// 注销指定 ID 的插件。
    func unregister(pluginID: String) {
        if let plugin = plugins.first(where: { $0.id == pluginID }) {
            unregister(plugin)
        }
    }
    
    /// 切换插件的启用状态。
    func togglePlugin(_ plugin: NovelCraftPlugin) {
        plugin.isEnabled.toggle()
        if plugin.isEnabled {
            classify(plugin)
        } else {
            unclassify(plugin)
        }
        objectWillChange.send()
    }
    
    // MARK: 内置插件注册
    
    /// 注册所有官方内置插件。应在应用启动时调用一次。
    func registerBuiltInPlugins() {
        register(WordCountEnhancementPlugin(), isBuiltIn: true)
        register(WritingPromptPlugin(), isBuiltIn: true)
        register(NameGeneratorPlugin(), isBuiltIn: true)
        register(SensitiveWordCheckPlugin(), isBuiltIn: true)
        register(RepeatedWordCheckPlugin(), isBuiltIn: true)
        register(TodoListPlugin(), isBuiltIn: true)
        #if os(macOS)
        register(DeviceMonitorPlugin(), isBuiltIn: true)
        #endif
    }
    
    /// 重置所有内置插件（恢复被注销的官方插件）。
    func resetBuiltInPlugins() {
        registerBuiltInPlugins()
    }
    
    // MARK: 扩展点查询
    
    /// 获取所有已启用插件贡献的工具栏按钮。
    var allToolbarItems: [PluginToolbarItem] {
        toolbarContributors
            .filter(\.isEnabled)
            .flatMap(\.toolbarItems)
    }
    
    /// 获取所有已启用插件贡献的导出格式。
    var allExportFormats: [PluginExportFormat] {
        exportContributors
            .filter(\.isEnabled)
            .flatMap(\.supportedFormats)
    }
    
    /// 获取所有已启用插件贡献的侧边栏面板。
    var allSidebarPanels: [PluginSidebarPanel] {
        sidebarContributors
            .filter(\.isEnabled)
            .flatMap(\.sidebarPanels)
    }
    
    /// 获取所有已启用插件贡献的章节动作。
    var allChapterActions: [PluginChapterAction] {
        chapterActionContributors
            .filter(\.isEnabled)
            .flatMap(\.chapterActions)
    }
    
    /// 按顺序执行所有已启用内容处理器，对章节文本进行链式处理。
    func processContent(_ content: String, chapter: Chapter) -> String {
        var result = content
        for processor in contentProcessors where processor.isEnabled {
            result = processor.process(content: result, chapter: chapter)
        }
        return result
    }
    
    /// 查找支持指定格式的导出插件。
    func exportContributor(for formatID: String) -> ExportFormatContributor? {
        exportContributors.first { contributor in
            contributor.isEnabled && contributor.supportedFormats.contains(where: { $0.id == formatID })
        }
    }
    
    // MARK: 私有辅助方法
    
    private func classify(_ plugin: NovelCraftPlugin) {
        if let contributor = plugin as? EditorToolbarContributor {
            if !toolbarContributors.contains(where: { $0.id == contributor.id }) {
                toolbarContributors.append(contributor)
            }
        }
        if let contributor = plugin as? ExportFormatContributor {
            if !exportContributors.contains(where: { $0.id == contributor.id }) {
                exportContributors.append(contributor)
            }
        }
        if let contributor = plugin as? SidebarPanelContributor {
            if !sidebarContributors.contains(where: { $0.id == contributor.id }) {
                sidebarContributors.append(contributor)
            }
        }
        if let processor = plugin as? ContentProcessor {
            if !contentProcessors.contains(where: { $0.id == processor.id }) {
                contentProcessors.append(processor)
            }
        }
        if let contributor = plugin as? ChapterActionContributor {
            if !chapterActionContributors.contains(where: { $0.id == contributor.id }) {
                chapterActionContributors.append(contributor)
            }
        }
    }
    
    private func unclassify(_ plugin: NovelCraftPlugin) {
        toolbarContributors.removeAll { $0.id == plugin.id }
        exportContributors.removeAll { $0.id == plugin.id }
        sidebarContributors.removeAll { $0.id == plugin.id }
        contentProcessors.removeAll { $0.id == plugin.id }
        chapterActionContributors.removeAll { $0.id == plugin.id }
    }
}

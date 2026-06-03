import SwiftUI

/// 插件管理中心视图。
///
/// 独立的插件管理页面，支持查看、启用/禁用、删除插件，以及恢复官方内置插件。
struct PluginSettingsView: View {
    @StateObject private var pluginManager = PluginManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var pluginToDelete: (any NovelCraftPlugin)? = nil
    @State private var showDeleteConfirm = false
    @State private var showResetConfirm = false
    @State private var selectedPluginDetailID: String? = nil
    @State private var selectedPluginConfigID: String? = nil
    
    /// 外部插件列表（可删除）
    private var externalPlugins: [any NovelCraftPlugin] {
        pluginManager.plugins.filter { !pluginManager.isBuiltIn(pluginID: $0.id) }
    }
    
    /// 内置插件列表（不可删除）
    private var builtInPlugins: [any NovelCraftPlugin] {
        pluginManager.plugins.filter { pluginManager.isBuiltIn(pluginID: $0.id) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Text("插件管理")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // 恢复内置插件按钮
                if builtInPlugins.count < 5 {
                    Button {
                        showResetConfirm = true
                    } label: {
                        Label("恢复官方插件", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                }
                
                Button {
                    dismiss()
                } label: {
                    Text("完成")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            if pluginManager.plugins.isEmpty {
                emptyStateView
            } else {
                pluginListView
            }
        }
        .frame(minWidth: 520, minHeight: 400)
        .alert("确认删除插件", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                if let plugin = pluginToDelete {
                    pluginManager.unregister(plugin)
                    pluginToDelete = nil
                }
            }
            Button("取消", role: .cancel) {
                pluginToDelete = nil
            }
        } message: {
            if let plugin = pluginToDelete {
                Text("确定要删除插件「\(plugin.name)」吗？删除后该插件提供的功能将不再可用。")
            }
        }
        .alert("恢复官方插件", isPresented: $showResetConfirm) {
            Button("恢复", role: .none) {
                pluginManager.resetBuiltInPlugins()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这将重新注册所有 NovelCraft 官方内置插件。已存在的插件不会被重复添加。")
        }
        .sheet(isPresented: Binding(
            get: { selectedPluginDetailID != nil },
            set: { if !$0 { selectedPluginDetailID = nil } }
        )) {
            if let id = selectedPluginDetailID,
               let plugin = pluginManager.plugins.first(where: { $0.id == id }) {
                PluginDetailSheet(plugin: plugin)
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedPluginConfigID != nil },
            set: { if !$0 { selectedPluginConfigID = nil } }
        )) {
            if let id = selectedPluginConfigID,
               let plugin = pluginManager.plugins.first(where: { $0.id == id }) as? any PluginConfigurable {
                PluginConfigSheet(plugin: plugin)
            }
        }
    }
    
    // MARK: - 空状态
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("暂无已安装插件")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Text("点击下方按钮恢复官方内置插件，或添加自定义插件。")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Button {
                showResetConfirm = true
            } label: {
                Label("恢复官方插件", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 插件列表
    
    private var pluginListView: some View {
        List {
            // 内置插件区域
            if !builtInPlugins.isEmpty {
                Section {
                    ForEach(Array(builtInPlugins.enumerated()), id: \.offset) { _, plugin in
                        PluginManagementRow(
                            plugin: plugin,
                            isBuiltIn: true,
                            onToggle: { pluginManager.togglePlugin(plugin) },
                            onDelete: nil,
                            onDetail: { selectedPluginDetailID = plugin.id },
                            onConfig: { selectedPluginConfigID = plugin.id }
                        )
                    }
                } header: {
                    HStack {
                        Text("官方内置插件")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(builtInPlugins.count) 个")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // 外部插件区域
            if !externalPlugins.isEmpty {
                Section {
                    ForEach(Array(externalPlugins.enumerated()), id: \.offset) { _, plugin in
                        PluginManagementRow(
                            plugin: plugin,
                            isBuiltIn: false,
                            onToggle: { pluginManager.togglePlugin(plugin) },
                            onDelete: {
                                pluginToDelete = plugin
                                showDeleteConfirm = true
                            },
                            onDetail: { selectedPluginDetailID = plugin.id },
                            onConfig: { selectedPluginConfigID = plugin.id }
                        )
                    }
                } header: {
                    HStack {
                        Text("外部插件")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(externalPlugins.count) 个")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }
}

// MARK: - 插件管理行

struct PluginManagementRow: View {
    let plugin: any NovelCraftPlugin
    let isBuiltIn: Bool
    let onToggle: () -> Void
    let onDelete: (() -> Void)?
    let onDetail: () -> Void
    let onConfig: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 状态指示点
            Circle()
                .fill(plugin.isEnabled ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(plugin.name)
                        .font(.system(size: 14, weight: .semibold))
                    
                    if isBuiltIn {
                        Text("内置")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(4)
                    }
                    
                    Text("v\(plugin.version)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Text(plugin.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                // 能力标签
                HStack(spacing: 4) {
                    ForEach(Array(capabilityBadges.enumerated()), id: \.offset) { _, badge in
                        HStack(spacing: 2) {
                            Image(systemName: badge.icon)
                                .font(.caption2)
                            Text(badge.title)
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            // 开关
            Toggle("", isOn: Binding(
                get: { plugin.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .frame(width: 44)
            
            // 固定宽度的操作按钮组，保证所有行对齐
            HStack(spacing: 8) {
                // 详情按钮
                Button {
                    onDetail()
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("查看详情")
                .frame(width: 24)
                
                // 配置按钮（不可配置时禁用）
                let isConfigurable = plugin is any PluginConfigurable
                Button {
                    if isConfigurable { onConfig() }
                } label: {
                    Image(systemName: "gear")
                        .foregroundStyle(.secondary)
                        .opacity(isConfigurable ? 1.0 : 0.3)
                }
                .buttonStyle(.borderless)
                .help(isConfigurable ? "插件配置" : "该插件不支持配置")
                .disabled(!isConfigurable)
                .frame(width: 24)
                
                // 删除按钮（内置插件时禁用）
                let canDelete = onDelete != nil
                Button {
                    if canDelete, let action = onDelete { action() }
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .opacity(canDelete ? 0.7 : 0.2)
                }
                .buttonStyle(.borderless)
                .help(canDelete ? "删除插件" : "内置插件不可删除")
                .disabled(!canDelete)
                .frame(width: 24)
            }
            .frame(width: 96)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onDetail()
        }
    }
    
    private var capabilityBadges: [(icon: String, title: String)] {
        var badges: [(String, String)] = []
        if plugin.hasEditorToolbarButton {
            badges.append(("rectangle.and.pencil.and.ellipsis", "工具栏"))
        }
        if plugin is any ExportFormatContributor {
            badges.append(("square.and.arrow.up", "导出"))
        }
        if plugin is any SidebarPanelContributor {
            badges.append(("sidebar.right", "面板"))
        }
        if plugin is any ContentProcessor {
            badges.append(("gearshape.2", "处理"))
        }
        if plugin is any ChapterActionContributor {
            badges.append(("cursorarrow.click", "动作"))
        }
        return badges
    }
}

// MARK: - 插件详情弹窗

struct PluginDetailSheet: View {
    let plugin: any NovelCraftPlugin
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("插件详情")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    detailRow(title: "名称", value: plugin.name)
                    detailRow(title: "标识符", value: plugin.id)
                    detailRow(title: "版本", value: plugin.version)
                    detailRow(title: "作者", value: plugin.author)
                    detailRow(title: "状态", value: plugin.isEnabled ? "已启用" : "已禁用")
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("简介")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(plugin.description)
                            .font(.body)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("扩展能力")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        let capabilities = capabilityList
                        if capabilities.isEmpty {
                            Text("无")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(capabilities.enumerated()), id: \.offset) { _, cap in
                                    HStack(spacing: 6) {
                                        Image(systemName: cap.icon)
                                            .foregroundStyle(Color.accentColor)
                                            .frame(width: 18)
                                        Text(cap.name)
                                            .font(.body)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 360, idealWidth: 400, minHeight: 300, idealHeight: 400)
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
            Spacer()
        }
    }
    
    private var capabilityList: [(icon: String, name: String)] {
        var list: [(String, String)] = []
        if plugin.hasEditorToolbarButton {
            list.append(("rectangle.and.pencil.and.ellipsis", "编辑器工具栏扩展"))
        }
        if plugin is any ExportFormatContributor {
            list.append(("square.and.arrow.up", "导出格式扩展"))
        }
        if plugin is any SidebarPanelContributor {
            list.append(("sidebar.right", "侧边栏面板扩展"))
        }
        if plugin is any ContentProcessor {
            list.append(("gearshape.2", "内容处理器"))
        }
        if plugin is any ChapterActionContributor {
            list.append(("cursorarrow.click", "章节动作扩展"))
        }
        return list
    }
}

// MARK: - 插件配置弹窗

struct PluginConfigSheet: View {
    let plugin: any PluginConfigurable
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(plugin.name) 配置")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            
            Divider()
            
            plugin.configurationView
        }
        .frame(minWidth: 360, idealWidth: 400, minHeight: 300, idealHeight: 400)
    }
}

// MARK: - 插件可标识辅助

/// 插件包装器，用于在 SwiftUI 列表中提供稳定的 Identifiable 支持。
struct PluginWrapper: Identifiable {
    let id: String
    let plugin: any NovelCraftPlugin
}

extension PluginManager {
    /// 将所有插件包装为 Identifiable 数组，供 SwiftUI ForEach 使用。
    var wrappedPlugins: [PluginWrapper] {
        plugins.map { PluginWrapper(id: $0.id, plugin: $0) }
    }
}

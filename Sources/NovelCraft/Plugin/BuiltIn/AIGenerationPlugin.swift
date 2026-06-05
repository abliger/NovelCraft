import SwiftUI
import SwiftData

/// AI 生成插件。
///
/// 通过策略模式支持多品牌切换，目前内置 DeepSeek 实现。
/// 在编辑器工具栏提供「AI 生成」按钮，点击后在右侧侧滑出生成面板。
@MainActor
final class AIGenerationPlugin: NovelCraftPlugin, EditorToolbarContributor, PluginConfigurable {
    let id = "com.novelcraft.plugins.aigeneration"
    let name = "AI 生成"
    let description = "基于 DeepSeek 等大模型的 AI 写作辅助，支持续写、扩写等功能。"
    let version = "1.0.0"
    let author = "NovelCraft 官方"
    var isEnabled: Bool = true
    var hasEditorToolbarButton: Bool { true }
    
    private weak var context: PluginContext?
    
    /// 所有可用的生成策略（品牌）。
    let strategies: [any AIGenerationStrategy] = [
        DeepSeekStrategy()
    ]
    
    func setup(context: PluginContext) {
        self.context = context
    }
    
    func teardown() {
        context = nil
    }
    
    // MARK: - EditorToolbarContributor
    
    var toolbarItems: [PluginToolbarItem] {
        [
            PluginToolbarItem(
                id: "\(id).openpanel",
                icon: "sparkles",
                tooltip: "AI 生成面板"
            ) { [weak self] in
                NotificationCenter.default.post(
                    name: .aiGenerationPanelToggle,
                    object: nil,
                    userInfo: ["pluginID": self?.id as Any]
                )
            }
        ]
    }
    
    // MARK: - PluginConfigurable
    
    var configurationView: AnyView {
        AnyView(AIGenerationConfigView(pluginID: id))
    }
    
    // MARK: - 配置读写便捷方法
    
    var apiKey: String {
        get { PluginConfigStore.string(pluginID: id, key: "apiKey") ?? "" }
        set { PluginConfigStore.set(newValue, pluginID: id, key: "apiKey") }
    }
    
    var selectedStrategyID: String {
        get { PluginConfigStore.string(pluginID: id, key: "strategy") ?? "deepseek" }
        set { PluginConfigStore.set(newValue, pluginID: id, key: "strategy") }
    }
    
    var selectedModel: String {
        get { PluginConfigStore.string(pluginID: id, key: "model") ?? "deepseek-chat" }
        set { PluginConfigStore.set(newValue, pluginID: id, key: "model") }
    }
    
    // MARK: - 生成逻辑
    
    func generateContent(prompt: String, strategyID: String, apiKey: String, model: String) async throws -> String {
        guard let strategy = strategies.first(where: { $0.id == strategyID }) else {
            throw AIGenerationError.apiError("未找到策略: \(strategyID)")
        }
        return try await strategy.generate(apiKey: apiKey, prompt: prompt, model: model)
    }
}

// MARK: - 配置面板视图

struct AIGenerationConfigView: View {
    let pluginID: String
    
    @State private var apiKey: String = ""
    @State private var selectedStrategyID: String = "deepseek"
    @State private var selectedModel: String = "deepseek-chat"
    
    private var plugin: AIGenerationPlugin? {
        PluginManager.shared.plugins.first(where: { $0.id == pluginID }) as? AIGenerationPlugin
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI 生成配置")
                .font(.headline)
            
            // 品牌选择
            VStack(alignment: .leading, spacing: 6) {
                Text("品牌")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $selectedStrategyID) {
                    ForEach(plugin?.strategies ?? [], id: \.id) { strategy in
                        Text(strategy.displayName).tag(strategy.id)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedStrategyID) { _, newID in
                    if let strategy = plugin?.strategies.first(where: { $0.id == newID }) {
                        selectedModel = strategy.defaultModel
                    }
                    saveConfig()
                }
            }
            
            // API Key
            VStack(alignment: .leading, spacing: 6) {
                Text("API Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("输入 API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKey) { _, _ in saveConfig() }
            }
            
            // 模型选择
            VStack(alignment: .leading, spacing: 6) {
                Text("模型")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("模型名称", text: $selectedModel)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: selectedModel) { _, _ in saveConfig() }
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 300, minHeight: 250)
        .onAppear {
            loadConfig()
        }
    }
    
    private func loadConfig() {
        apiKey = PluginConfigStore.string(pluginID: pluginID, key: "apiKey") ?? ""
        selectedStrategyID = PluginConfigStore.string(pluginID: pluginID, key: "strategy") ?? "deepseek"
        selectedModel = PluginConfigStore.string(pluginID: pluginID, key: "model") ?? "deepseek-chat"
    }
    
    private func saveConfig() {
        PluginConfigStore.set(apiKey, pluginID: pluginID, key: "apiKey")
        PluginConfigStore.set(selectedStrategyID, pluginID: pluginID, key: "strategy")
        PluginConfigStore.set(selectedModel, pluginID: pluginID, key: "model")
    }
}

// MARK: - 通知名称

extension Notification.Name {
    static let aiGenerationPanelToggle = Notification.Name("NovelCraft.AIGenerationPanelToggle")
}

// MARK: - 面板视图

struct AIGenerationPanelView: View {
    @Environment(\.modelContext) private var modelContext
    
    let chapter: Chapter
    
    @State private var generationMode: GenerationMode = .continueWriting
    @State private var generatedText: String = ""
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil
    @State private var showConfig = false
    @State private var showPromptPreview = false
    @State private var promptPreviewText: String = ""
    @State private var showRuleEditor = false
    @State private var ruleText: String = ""
    @State private var customInstruction: String = ""
    
    @State private var apiKey: String = ""
    @State private var selectedStrategyID: String = "deepseek"
    @State private var selectedModel: String = "deepseek-chat"
    
    private let pluginID = "com.novelcraft.plugins.aigeneration"
    
    private var plugin: AIGenerationPlugin? {
        PluginManager.shared.plugins.first(where: { $0.id == pluginID }) as? AIGenerationPlugin
    }
    
    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    synopsisSection
                    
                    Divider()
                    
                    ruleSection
                    
                    Divider()
                    
                    modeSection
                    
                    actionSection
                    
                    if showPromptPreview {
                        promptPreviewSection
                    }
                    
                    resultSection
                }
                .padding()
            }
        }
        #if os(macOS)
        .frame(minWidth: 300, minHeight: 500)
        #endif
        .onAppear {
            loadConfig()
            loadRuleFromDisk()
        }
    }
    
    // MARK: - 子视图
    
    private var panelHeader: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
            Text("AI 生成")
                .font(.headline)
            Spacer()
            Button {
                withAnimation {
                    showConfig.toggle()
                }
            } label: {
                Image(systemName: "gear")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help(showConfig ? "收起配置" : "展开配置")
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private var synopsisSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .foregroundStyle(Color.accentColor)
                Text("章节细纲")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if chapter.synopsis.isEmpty {
                Text("暂无细纲，可在章节属性中添加。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(chapter.synopsis)
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var ruleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "doc.plaintext")
                    .foregroundStyle(Color.accentColor)
                Text("写作规范")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    withAnimation {
                        showRuleEditor.toggle()
                    }
                } label: {
                    Image(systemName: showRuleEditor ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help(showRuleEditor ? "收起" : "展开编辑")
            }
            
            if showRuleEditor {
                TextEditor(text: $ruleText)
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .frame(minHeight: 80)
                    .padding(6)
                    .scrollContentBackground(.hidden)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .onChange(of: ruleText) { _, newValue in
                        saveRuleToDisk(newValue)
                    }
            } else {
                if ruleText.isEmpty {
                    Text("暂无写作规范，展开后可编辑 rule.md。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(ruleText)
                        .font(.system(size: 12))
                        .lineSpacing(3)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("生成模式")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Picker("", selection: $generationMode) {
                Text("续写").tag(GenerationMode.continueWriting)
                Text("扩写").tag(GenerationMode.expand)
                Text("润色").tag(GenerationMode.polish)
                Text("改写").tag(GenerationMode.rewrite)
                Text("自定义").tag(GenerationMode.custom)
            }
            .pickerStyle(.segmented)
            
            Text(generationMode.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if generationMode == .rewrite || generationMode == .custom {
                VStack(alignment: .leading, spacing: 4) {
                    Text(generationMode == .rewrite ? "改写要求" : "自定义提示")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $customInstruction)
                        .font(.system(size: 13))
                        .lineSpacing(4)
                        .frame(minHeight: 60)
                        .padding(6)
                        .scrollContentBackground(.hidden)
                        .background(Color.secondary.opacity(0.06))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
    }
    
    private var actionSection: some View {
        VStack(spacing: 10) {
            if showConfig {
                configSection
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack(spacing: 12) {
                Button {
                    promptPreviewText = buildPrompt(includeContent: false)
                    withAnimation {
                        showPromptPreview.toggle()
                    }
                } label: {
                    Label(showPromptPreview ? "收起提示词" : "查看提示词", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button {
                    Task { await generate() }
                } label: {
                    Label(isGenerating ? "生成中…" : "开始生成", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty || isGenerating)
            }
            
            if apiKey.isEmpty {
                Text("⚠️ 尚未配置 API Key，点击右上角 ⚙️ 进行配置")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var configSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("配置")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack {
                Text("品牌")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)
                Picker("", selection: $selectedStrategyID) {
                    ForEach(plugin?.strategies ?? [], id: \.id) { strategy in
                        Text(strategy.displayName).tag(strategy.id)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedStrategyID) { _, newID in
                    if let strategy = plugin?.strategies.first(where: { $0.id == newID }) {
                        selectedModel = strategy.defaultModel
                    }
                }
            }
            
            HStack {
                Text("API Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)
                SecureField("输入 API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Text("模型")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)
                TextField("模型名称", text: $selectedModel)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
    
    private var promptPreviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("提示词预览（开发人员测试）")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    copyToClipboard(promptPreviewText)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("复制提示词")
            }
            
            ScrollView {
                Text(promptPreviewText)
                    .font(.system(size: 12, design: .monospaced))
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(minHeight: 120, maxHeight: 400)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !generatedText.isEmpty {
                Text("生成结果")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ScrollView {
                    Text(generatedText)
                        .font(.system(size: 13))
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(minHeight: 120, maxHeight: 300)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                
                HStack(spacing: 12) {
                    Button {
                        copyToClipboard(generatedText)
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        insertIntoChapter(generatedText)
                    } label: {
                        Label("插入编辑器", systemImage: "text.insert")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    // MARK: - 操作
    
    private func loadConfig() {
        apiKey = PluginConfigStore.string(pluginID: pluginID, key: "apiKey") ?? ""
        selectedStrategyID = PluginConfigStore.string(pluginID: pluginID, key: "strategy") ?? "deepseek"
        selectedModel = PluginConfigStore.string(pluginID: pluginID, key: "model") ?? "deepseek-chat"
    }
    
    private func saveConfig() {
        PluginConfigStore.set(apiKey, pluginID: pluginID, key: "apiKey")
        PluginConfigStore.set(selectedStrategyID, pluginID: pluginID, key: "strategy")
        PluginConfigStore.set(selectedModel, pluginID: pluginID, key: "model")
    }
    
    private func loadRuleFromDisk() {
        guard let project = chapter.volume?.project else { return }
        ruleText = FileSyncEngine.loadRuleFromDisk(project: project) ?? ""
    }
    
    private func saveRuleToDisk(_ text: String) {
        guard let project = chapter.volume?.project else { return }
        FileSyncEngine.syncRuleToDisk(text, project: project)
    }
    
    private func buildPrompt(includeContent: Bool = true) -> String {
        let modePrompt = generationMode.systemPrompt
        let project = chapter.volume?.project
        let agentContext = buildAgentContext(project: project)
        
        let synopsisText = chapter.synopsis.isEmpty ? "（无细纲）" : chapter.synopsis
        let currentVolumeTitle = chapter.volume?.title ?? "未命名卷"
        let contentText = includeContent ? chapter.content : "（章节内容已省略，实际发送时包含完整内容）"
        
        let ruleSection = ruleText.isEmpty ? "" : """
        
        ## 写作规范
        \(ruleText)
        """
        
        let instructionSection = customInstruction.isEmpty ? "" : """
        
        ## 用户额外指令
        \(customInstruction)
        """
        
        return """
        \(agentContext)
        
        ---
        \(ruleSection)
        
        \(modePrompt)
        \(instructionSection)
        
        当前卷：\(currentVolumeTitle)
        当前章节标题：\(chapter.title)
        本章细纲：\(synopsisText)
        
        当前章节已写内容：
        \(contentText)
        """
    }
    
    private func buildAgentContext(project: Project?) -> String {
        guard let project = project else { return "" }
        
        var sections: [String] = []
        
        sections.append("""
        # 小说创作助手指令
        
        你是一位专业中文小说创作助手，正在为作品《\(project.title)》进行写作。
        作者：\(project.author.isEmpty ? "匿名" : project.author)
        """)
        
        if !project.summary.isEmpty {
            sections.append("作品简介：\(project.summary)")
        }
        
        if !project.bookOutline.isEmpty {
            sections.append("""
            
            ## 整书大纲
            \(project.bookOutline)
            """)
        }
        
        if let volume = chapter.volume,
           let volumeOutline = findVolumeOutline(for: volume, in: project) {
            sections.append("""
            
            ## 本卷大纲：\(volumeOutline.title)
            \(volumeOutline.content.isEmpty ? "（无卷级概述）" : volumeOutline.content)
            """)
            
            let detailNodes = volumeOutline.children.sorted { $0.order < $1.order }
            if !detailNodes.isEmpty {
                var detailText = "\n### 本卷细纲\n"
                for node in detailNodes {
                    detailText += "- \(node.title)"
                    if !node.content.isEmpty {
                        detailText += "：\(node.content)"
                    }
                    detailText += "\n"
                }
                sections.append(detailText)
            }
        }
        
        let characters = project.characters.sorted { $0.order < $1.order }
        if !characters.isEmpty {
            var charText = "\n## 角色设定\n"
            for char in characters.prefix(8) {
                charText += "\n### \(char.name)"
                if !char.aliases.isEmpty { charText += "（\(char.aliases)）" }
                charText += "\n"
                if !char.gender.isEmpty { charText += "- 性别：\(char.gender)\n" }
                if !char.age.isEmpty { charText += "- 年龄：\(char.age)\n" }
                if !char.appearance.isEmpty { charText += "- 外貌：\(char.appearance)\n" }
                if !char.personality.isEmpty { charText += "- 性格：\(char.personality)\n" }
                if !char.background.isEmpty { charText += "- 背景：\(char.background)\n" }
                if !char.goals.isEmpty { charText += "- 目标：\(char.goals)\n" }
                if !char.fate.isEmpty { charText += "- 命运：\(char.fate)\n" }
                if !char.relationships.isEmpty { charText += "- 关系：\(char.relationships)\n" }
            }
            sections.append(charText)
        }
        
        let worldSettings = project.worldSettings.sorted { $0.order < $1.order }
        if !worldSettings.isEmpty {
            var settingText = "\n## 世界观设定\n"
            for setting in worldSettings.prefix(10) {
                settingText += "\n### \(setting.title)（\(setting.category)）\n\(setting.content)\n"
            }
            sections.append(settingText)
        }
        
        return sections.joined(separator: "\n")
    }
    
    private func findVolumeOutline(for volume: Volume, in project: Project) -> OutlineNode? {
        let sortedVolumes = project.volumes.sorted { $0.order < $1.order }
        guard let volumeIndex = sortedVolumes.firstIndex(where: { $0.id == volume.id }) else {
            return nil
        }
        
        let volumeOutlines = project.outlineNodes
            .filter { $0.parent == nil }
            .sorted { $0.order < $1.order }
        
        if volumeIndex < volumeOutlines.count {
            return volumeOutlines[volumeIndex]
        }
        
        return volumeOutlines.first { $0.title == volume.title }
    }
    
    private func generate() async {
        guard let plugin = plugin else { return }
        guard !apiKey.isEmpty else {
            errorMessage = "请先填写 API Key"
            return
        }
        
        let prompt = buildPrompt()
        
        isGenerating = true
        errorMessage = nil
        generatedText = ""
        
        do {
            let text = try await plugin.generateContent(
                prompt: prompt,
                strategyID: selectedStrategyID,
                apiKey: apiKey,
                model: selectedModel
            )
            generatedText = text
        } catch let err as AIGenerationError {
            errorMessage = err.localizedDescription
        } catch {
            errorMessage = "生成失败: \(error.localizedDescription)"
        }
        
        isGenerating = false
    }
    
    private func insertIntoChapter(_ text: String) {
        chapter.content += "\n\(text)\n"
        chapter.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

// MARK: - 生成模式

enum GenerationMode: String, CaseIterable, Identifiable {
    case continueWriting
    case expand
    case polish
    case rewrite
    case custom
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .continueWriting: return "续写"
        case .expand: return "扩写"
        case .polish: return "润色"
        case .rewrite: return "改写"
        case .custom: return "自定义"
        }
    }
    
    var description: String {
        switch self {
        case .continueWriting:
            return "根据当前章节内容与细纲，继续写出后续情节，保持原有文风与设定。"
        case .expand:
            return "对当前片段进行扩写，增加细节描写、心理活动与环境渲染，让内容更丰满。"
        case .polish:
            return "优化语句表达，提升文学性，同时保持原意不变。"
        case .rewrite:
            return "以不同角度或风格重新表达，保留核心情节但改变叙述方式。"
        case .custom:
            return "根据自定义提示词进行生成。"
        }
    }
    
    var systemPrompt: String {
        switch self {
        case .continueWriting:
            return "请根据提供的上下文，继续写出后续内容。保持原有的文风、人物设定和情节走向，自然衔接。"
        case .expand:
            return "请将提供的片段进行扩写，增加细节描写、心理活动和环境渲染，让内容更加丰满生动。"
        case .polish:
            return "请对提供的文本进行润色，优化语句表达，提升文学性，同时保持原意不变。"
        case .rewrite:
            return "请以不同的角度或风格重新表达以下内容，保留核心情节但改变叙述方式。"
        case .custom:
            return ""
        }
    }
}

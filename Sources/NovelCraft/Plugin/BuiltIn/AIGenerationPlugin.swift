import SwiftUI
import SwiftData

/// AI 生成插件。
///
/// 通过策略模式支持多品牌切换，目前内置 DeepSeek 实现。
/// 在编辑器工具栏提供「AI 生成」按钮，点击后在侧边栏打开生成面板。
@MainActor
final class AIGenerationPlugin: NovelCraftPlugin, EditorToolbarContributor {
    let id = "com.novelcraft.plugins.aigeneration"
    let name = "AI 生成"
    let description = "基于 DeepSeek 等大模型的 AI 写作辅助，支持续写、扩写、润色等功能。"
    let version = "1.0.0"
    let author = "NovelCraft 官方"
    var isEnabled: Bool = true
    
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
                    userInfo: ["pluginID": self?.id]
                )
            }
        ]
    }
    
    // MARK: - 生成逻辑
    
    func generateContent(prompt: String, strategyID: String, apiKey: String, model: String) async throws -> String {
        guard let strategy = strategies.first(where: { $0.id == strategyID }) else {
            throw AIGenerationError.apiError("未找到策略: \(strategyID)")
        }
        return try await strategy.generate(apiKey: apiKey, prompt: prompt, model: model)
    }
}

// MARK: - 通知名称

extension Notification.Name {
    static let aiGenerationPanelToggle = Notification.Name("NovelCraft.AIGenerationPanelToggle")
}

// MARK: - 面板视图

struct AIGenerationPanelView: View {
    @AppStorage("ai.apiKey") private var apiKey: String = ""
    @AppStorage("ai.selectedStrategy") private var selectedStrategyID: String = "deepseek"
    @AppStorage("ai.selectedModel") private var selectedModel: String = "deepseek-chat"
    
    @State private var prompt: String = ""
    @State private var generatedText: String = ""
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil
    @State private var generationMode: GenerationMode = .continueWriting
    @State private var showConfig = false
    
    private var plugin: AIGenerationPlugin? {
        PluginManager.shared.plugins.first(where: { $0.id == "com.novelcraft.plugins.aigeneration" }) as? AIGenerationPlugin
    }
    
    private var context: PluginContext {
        PluginManager.shared.context
    }
    
    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    configSection
                    modeSection
                    promptSection
                    actionSection
                    resultSection
                }
                .padding()
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 500)
        #endif
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
                Image(systemName: showConfig ? "gear" : "gear")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help(showConfig ? "收起配置" : "展开配置")
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private var configSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showConfig {
                Text("配置")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                // 品牌选择
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
                
                // API Key
                HStack {
                    Text("API Key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)
                    SecureField("输入 API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                }
                
                // 模型选择
                HStack {
                    Text("模型")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)
                    TextField("模型名称", text: $selectedModel)
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                HStack {
                    Text("品牌: \(plugin?.strategies.first(where: { $0.id == selectedStrategyID })?.displayName ?? selectedStrategyID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("模型: \(selectedModel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if apiKey.isEmpty {
                    Text("⚠️ 尚未配置 API Key，点击右上角 ⚙️ 进行配置")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("API Key: \(String(repeating: "•", count: min(apiKey.count, 12)))")
                        .font(.caption)
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
                ForEach(GenerationMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("提示词")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            TextEditor(text: $prompt)
                .font(.system(size: 14))
                .frame(minHeight: 80)
                .padding(4)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    private var actionSection: some View {
        VStack(spacing: 8) {
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack(spacing: 12) {
                Button {
                    fillPromptFromContext()
                } label: {
                    Label("读取上下文", systemImage: "doc.text")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button {
                    Task { await generate() }
                } label: {
                    Label(isGenerating ? "生成中…" : "开始生成", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty || prompt.isEmpty || isGenerating)
            }
        }
    }
    
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !generatedText.isEmpty {
                Text("生成结果")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                TextEditor(text: $generatedText)
                    .font(.system(size: 14))
                    .frame(minHeight: 120)
                    .padding(4)
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
    
    private func fillPromptFromContext() {
        guard let chapter = context.selectedChapter else {
            prompt = ""
            return
        }
        let prefix = generationMode.systemPrompt
        prompt = "\(prefix)\n\n当前章节内容：\n\(chapter.content)\n\n请根据以上内容进行生成。"
    }
    
    private func generate() async {
        guard let plugin = plugin else { return }
        guard !apiKey.isEmpty else {
            errorMessage = "请先填写 API Key"
            return
        }
        guard !prompt.isEmpty else {
            errorMessage = "提示词不能为空"
            return
        }
        
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
        guard let chapter = context.selectedChapter else {
            errorMessage = "未选中章节"
            return
        }
        chapter.content += "\n\(text)\n"
        context.save()
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

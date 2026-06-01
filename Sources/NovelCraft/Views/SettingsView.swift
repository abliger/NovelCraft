import SwiftUI

/// 应用设置视图：管理用户偏好配置，包括外观、编辑器行为与默认写作目标
struct SettingsView: View {
    
    // MARK: - AppStorage 偏好设置
    
    /// 主题模式：跟随系统 / 浅色 / 深色
    @AppStorage(ThemeManager.themeModeKey) private var themeMode: AppTheme = .system
    /// 编辑器字体大小（pt）
    @AppStorage("editorFontSize") private var editorFontSize: Double = 16
    /// 编辑器行间距（pt）
    @AppStorage("editorLineSpacing") private var editorLineSpacing: Double = 8
    /// 自动保存间隔（秒）
    @AppStorage("autoSaveInterval") private var autoSaveInterval: Double = 30
    /// 是否显示编辑器行号
    @AppStorage("showLineNumbers") private var showLineNumbers = false
    /// 是否启用打字机模式（光标保持在屏幕中央）
    @AppStorage("enableTypewriterMode") private var enableTypewriterMode = false
    /// 新建项目时的默认目标字数
    @AppStorage("defaultTargetWordCount") private var defaultTargetWordCount: Double = 50000
    /// 新建项目时的默认每日写作目标字数
    @AppStorage("defaultDailyGoal") private var defaultDailyGoal: Double = 2000
    /// 图片处理方式：0=引用原路径, 1=拷贝到项目, 2=下载网图
    @AppStorage("imageHandlingMode") private var imageHandlingMode = 1
    /// 是否允许下载网络图片
    @AppStorage("allowDownloadWebImages") private var allowDownloadWebImages = true
    
    #if os(iOS)
    @Environment(\.dismiss) private var dismiss
    #endif
    
    var body: some View {
        #if os(macOS)
        settingsForm
            .frame(minWidth: 400, minHeight: 400)
        #else
        NavigationStack {
            settingsForm
                .navigationTitle("设置")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { dismiss() }
                    }
                }
        }
        #endif
    }
    
    private var settingsForm: some View {
        Form {
            // MARK: - 外观
            Section("外观") {
                Picker("主题", selection: $themeMode) {
                    ForEach(AppTheme.allCases) { theme in
                        Label(theme.name, systemImage: theme.icon)
                            .tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                
                HStack {
                    Text("编辑器字体大小")
                    Spacer()
                    Slider(value: $editorFontSize, in: 12...32, step: 1)
                        .frame(width: 150)
                    Text("\(Int(editorFontSize))")
                        .frame(width: 30, alignment: .trailing)
                }
                
                HStack {
                    Text("行间距")
                    Spacer()
                    Slider(value: $editorLineSpacing, in: 0...20, step: 1)
                        .frame(width: 150)
                    Text("\(Int(editorLineSpacing))")
                        .frame(width: 30, alignment: .trailing)
                }
                
                Toggle("显示行号", isOn: $showLineNumbers)
            }
            
            // MARK: - 编辑
            Section("编辑") {
                Toggle("打字机模式（光标居中）", isOn: $enableTypewriterMode)
                
                HStack {
                    Text("自动保存间隔（秒）")
                    Spacer()
                    Slider(value: $autoSaveInterval, in: 5...300, step: 5)
                        .frame(width: 150)
                    Text("\(Int(autoSaveInterval))")
                        .frame(width: 40, alignment: .trailing)
                }
            }
            
            // MARK: - 默认目标
            Section("默认目标") {
                HStack {
                    Text("默认目标字数")
                    Spacer()
                    TextField("", value: $defaultTargetWordCount, format: .number)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("默认每日目标")
                    Spacer()
                    TextField("", value: $defaultDailyGoal, format: .number)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            // MARK: - 图片
            Section("图片") {
                Picker("图片处理方式", selection: $imageHandlingMode) {
                    Text("引用原路径").tag(0)
                    Text("拷贝到项目").tag(1)
                    Text("下载网图到项目").tag(2)
                }
                
                Toggle("允许下载网络图片", isOn: $allowDownloadWebImages)
                    .disabled(imageHandlingMode != 2)
            }
            
            // MARK: - 关于
            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("开发者")
                    Spacer()
                    Text("NovelCraft Team")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

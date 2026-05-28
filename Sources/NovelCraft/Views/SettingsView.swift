import SwiftUI

struct SettingsView: View {
    @AppStorage("themeMode") private var themeMode = 0
    @AppStorage("editorFontSize") private var editorFontSize: Double = 16
    @AppStorage("editorLineSpacing") private var editorLineSpacing: Double = 8
    @AppStorage("autoSaveInterval") private var autoSaveInterval: Double = 30
    @AppStorage("showLineNumbers") private var showLineNumbers = false
    @AppStorage("enableTypewriterMode") private var enableTypewriterMode = false
    @AppStorage("defaultTargetWordCount") private var defaultTargetWordCount: Double = 50000
    @AppStorage("defaultDailyGoal") private var defaultDailyGoal: Double = 2000
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("外观") {
                    Picker("主题", selection: $themeMode) {
                        Text("跟随系统").tag(0)
                        Text("浅色").tag(1)
                        Text("深色").tag(2)
                    }
                    
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
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .frame(minWidth: 450, minHeight: 500)
    }
}

import SwiftUI
import UniformTypeIdentifiers

/// 图片插入面板，支持本地文件选择、网络 URL 输入，并根据设置处理图片。
struct ImageInsertView: View {
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    /// 插入后回调，参数为 Markdown 图片语法字符串
    let onInsert: (String) -> Void
    
    /// 图片处理方式（从设置读取）
    @AppStorage("imageHandlingMode") private var imageHandlingMode = 1
    /// 是否允许下载网络图片
    @AppStorage("allowDownloadWebImages") private var allowDownloadWebImages = true
    
    /// 当前标签页
    @State private var selectedTab: ImageSourceTab = .local
    /// 网络图片 URL 输入
    @State private var webURL = ""
    /// 图片说明文字（alt）
    @State private var altText = ""
    /// 是否显示文件选择器
    @State private var showFileImporter = false
    /// 选中的本地文件 URL
    @State private var selectedFileURL: URL?
    /// 处理中的加载状态
    @State private var isProcessing = false
    /// 错误提示
    @State private var errorMessage: String?
    
    enum ImageSourceTab: String, CaseIterable {
        case local = "本地文件"
        case web = "网络地址"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("来源", selection: $selectedTab) {
                    ForEach(ImageSourceTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                Divider()
                
                Form {
                    Section("图片说明") {
                        TextField("输入图片说明文字…", text: $altText)
                    }
                    
                    switch selectedTab {
                    case .local:
                        localSection
                    case .web:
                        webSection
                    }
                    
                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.callout)
                        }
                    }
                }
                .formStyle(.grouped)
                
                Spacer()
            }
            .navigationTitle("插入图片")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("插入") {
                        Task { await processAndInsert() }
                    }
                    .disabled(!canInsert || isProcessing)
                }
            }
            .frame(minWidth: 400, minHeight: 300)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.image, .png, .jpeg, .gif],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        selectedFileURL = url
                        // 如果没有输入 alt，自动使用文件名（不含扩展名）
                        if altText.isEmpty {
                            altText = url.deletingPathExtension().lastPathComponent
                        }
                    }
                case .failure(let error):
                    errorMessage = "选择文件失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - 本地文件区域
    
    private var localSection: some View {
        Section("本地图片") {
            VStack(spacing: 12) {
                if let url = selectedFileURL {
                    HStack {
                        Image(systemName: "photo")
                            .foregroundStyle(Color.accentColor)
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            selectedFileURL = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                } else {
                    Button {
                        showFileImporter = true
                    } label: {
                        Label("选择图片文件…", systemImage: "folder")
                    }
                }
            }
        }
    }
    
    // MARK: - 网络地址区域
    
    private var webSection: some View {
        Section("网络图片") {
            TextField("输入图片 URL…", text: $webURL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
        }
    }
    
    // MARK: - 插入逻辑
    
    private var canInsert: Bool {
        switch selectedTab {
        case .local:
            return selectedFileURL != nil
        case .web:
            return !webURL.isEmpty && URL(string: webURL) != nil
        }
    }
    
    @MainActor
    private func processAndInsert() async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        
        let mode = ImageAssetEngine.HandlingMode(rawValue: imageHandlingMode) ?? .copyLocal
        let finalAlt = altText.isEmpty ? "图片" : altText
        
        switch selectedTab {
        case .local:
            guard let url = selectedFileURL else { return }
            if !ImageAssetEngine.isImageFile(url) {
                errorMessage = "选择的文件不是支持的图片格式"
                return
            }
            // security-scoped resource 访问
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }
            let path = await ImageAssetEngine.processImage(url: url, project: project, mode: mode)
            let markdown = "![\(finalAlt)](\(path))"
            onInsert(markdown)
            dismiss()
            
        case .web:
            guard let url = URL(string: webURL), url.scheme?.hasPrefix("http") == true else {
                errorMessage = "URL 格式不正确"
                return
            }
            // 若设置为「下载网图」但禁用了下载权限，网络图片回退到引用原 URL
            let effectiveMode: ImageAssetEngine.HandlingMode = (mode == .downloadWeb && !allowDownloadWebImages) ? .reference : mode
            let path = await ImageAssetEngine.processImage(url: url, project: project, mode: effectiveMode)
            let markdown = "![\(finalAlt)](\(path))"
            onInsert(markdown)
            dismiss()
        }
    }
}

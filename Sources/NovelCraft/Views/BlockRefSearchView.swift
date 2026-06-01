import SwiftUI
import SwiftData

/// 内容块搜索与选择面板，用于在编辑器中插入双向链接。
struct BlockRefSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let project: Project
    /// 插入后回调，参数为 (targetID, title, isEmbed)
    let onSelect: (UUID, String, Bool) -> Void
    
    @State private var searchText = ""
    @State private var isEmbedMode = false
    @State private var allBlocks: [BlockMeta] = []
    
    var filteredBlocks: [BlockMeta] {
        if searchText.isEmpty { return allBlocks }
        let lower = searchText.lowercased()
        return allBlocks.filter {
            $0.title.lowercased().contains(lower) ||
            $0.type.rawValue.lowercased().contains(lower)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索内容块…", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                
                // 模式切换
                Picker("模式", selection: $isEmbedMode) {
                    Text("引用").tag(false)
                    Text("嵌入").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                Divider()
                
                // 内容块列表
                List(filteredBlocks) { block in
                    Button {
                        onSelect(block.id, block.title, isEmbedMode)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: block.type.icon)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(block.title.isEmpty ? "未命名" : block.title)
                                    .font(.body)
                                    .lineLimit(1)
                                Text(block.type.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: isEmbedMode ? "doc.text.magnifyingglass" : "link")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
            #if os(macOS)
            .frame(width: 400, height: 500)
            #endif
            .navigationTitle("插入双向链接")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .task(id: project.id) {
            await MainActor.run {
                loadAllBlocks()
            }
        }
    }
    
    /// 加载项目中所有可作为内容块的实体。
    /// 在主线程执行（SwiftData @Model 关系属性访问要求同线程），
    /// 实际项目中内容块数量通常可控，若数量极大应考虑分页加载。
    private func loadAllBlocks() {
        var blocks: [BlockMeta] = []
        
        // 章节
        for volume in project.volumes {
            blocks.append(BlockMeta(id: volume.id, title: volume.title, type: .volume))
            for chapter in volume.chapters {
                blocks.append(BlockMeta(id: chapter.id, title: chapter.title, type: .chapter))
            }
        }
        
        // 便签
        for note in project.notes {
            let title = note.title.isEmpty ? "便签" : note.title
            blocks.append(BlockMeta(id: note.id, title: title, type: .note))
        }
        
        // 角色
        for character in project.characters {
            blocks.append(BlockMeta(id: character.id, title: character.name, type: .character))
        }
        
        // 世界观
        for ws in project.worldSettings {
            blocks.append(BlockMeta(id: ws.id, title: ws.title, type: .worldSetting))
        }
        
        // 大纲
        for node in project.outlineNodes {
            let title = node.title.isEmpty ? "大纲卡片" : node.title
            blocks.append(BlockMeta(id: node.id, title: title, type: .outline))
        }
        
        // 场景（也作为独立内容块列出）
        for volume in project.volumes {
            for chapter in volume.chapters {
                for scene in chapter.scenes {
                    blocks.append(BlockMeta(id: scene.id, title: scene.title, type: .scene))
                }
            }
        }
        
        allBlocks = blocks
    }
}

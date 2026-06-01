import SwiftUI

/// Block 风格编辑器主视图
///
/// 将 Markdown 内容解析为块列表，以 WYSIWYG 方式展示和编辑。
/// 支持块聚焦、缩放与大纲导航。
struct BlockEditorView: View {
    @Binding var markdownText: String
    var onChange: (() -> Void)?
    
    @State private var blocks: [ContentBlock] = []
    @State private var focusedBlockID: UUID? = nil
    @State private var zoomedBlockID: UUID? = nil
    @State private var showOutline: Bool = true
    
    /// 是否有块处于缩放模式
    private var isZoomed: Bool {
        zoomedBlockID != nil
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 大纲侧边栏
            if showOutline && !isZoomed {
                BlockOutlineView(
                    blocks: blocks,
                    selectedBlockID: Binding(
                        get: { focusedBlockID },
                        set: { focusedBlockID = $0 }
                    )
                )
                Divider()
            }
            
            // 主编辑区域
            VStack(spacing: 0) {
                // 块列表
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach($blocks) { $block in
                            let isFocused = focusedBlockID == block.id
                            let _ = zoomedBlockID == block.id
                            
                            BlockRowView(
                                block: $block,
                                isFocused: isFocused,
                                isZoomed: isZoomed,
                                onFocus: { focusedBlockID = block.id },
                                onZoom: { toggleZoom(blockID: block.id) },
                                onDelete: { deleteBlock(id: block.id) },
                                onConvert: { newType in convertBlock(id: block.id, to: newType) }
                            )
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // 底部添加块按钮
                if !isZoomed {
                    Button {
                        addBlock(at: blocks.count)
                    } label: {
                        Label("添加段落", systemImage: "plus.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                }
            }
            
            // 缩放模式下的退出按钮
            if isZoomed {
                VStack {
                    Button {
                        zoomedBlockID = nil
                    } label: {
                        Label("退出聚焦", systemImage: "arrow.down.right.and.arrow.up.left")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                    Spacer()
                }
                .frame(width: 120)
            }
        }
        .onAppear {
            blocks = BlockMarkdownConverter.parse(markdownText)
        }
        .onChange(of: markdownText) { _, newValue in
            let serialized = BlockMarkdownConverter.serialize(blocks)
            if serialized != newValue {
                blocks = BlockMarkdownConverter.parse(newValue)
            }
        }
        .onChange(of: blocks) { _, _ in
            syncToMarkdown()
        }
    }
    
    // MARK: - 块操作
    
    private func addBlock(at index: Int) {
        let newBlock = ContentBlock(type: .paragraph, content: "")
        blocks.insert(newBlock, at: min(index, blocks.count))
        focusedBlockID = newBlock.id
    }
    
    private func deleteBlock(id: UUID) {
        blocks.removeAll { $0.id == id }
        if focusedBlockID == id {
            focusedBlockID = nil
        }
        if zoomedBlockID == id {
            zoomedBlockID = nil
        }
    }
    
    private func convertBlock(id: UUID, to type: BlockType) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        var block = blocks[index]
        
        // 类型转换时的内容处理
        if block.type == .unorderedList && type == .paragraph {
            block.content = block.content
                .split(separator: "\n")
                .map { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("- ") {
                        return String(trimmed.dropFirst(2))
                    }
                    return String(line)
                }
                .joined(separator: "\n")
        }
        
        block.type = type
        blocks[index] = block
    }
    
    private func toggleZoom(blockID: UUID) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if zoomedBlockID == blockID {
                zoomedBlockID = nil
            } else {
                zoomedBlockID = blockID
                focusedBlockID = blockID
            }
        }
    }
    
    private func syncToMarkdown() {
        let newMarkdown = BlockMarkdownConverter.serialize(blocks)
        if newMarkdown != markdownText {
            markdownText = newMarkdown
            onChange?()
        }
    }
}

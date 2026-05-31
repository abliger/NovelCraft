import SwiftUI

// MARK: - 通用块行容器

/// 块行视图，包裹具体块内容，提供聚焦高亮、左侧操作栏与悬浮菜单。
struct BlockRowView: View {
    @Binding var block: ContentBlock
    var isFocused: Bool
    var isZoomed: Bool
    var onFocus: () -> Void
    var onZoom: () -> Void
    var onDelete: () -> Void
    var onConvert: (BlockType) -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            // 左侧块标识与操作
            BlockLeftHandle(
                block: block,
                isFocused: isFocused,
                onZoom: onZoom,
                onDelete: onDelete,
                onConvert: onConvert
            )
            .opacity(isFocused ? 1 : 0.3)
            
            // 块内容
            BlockContentView(block: $block, isFocused: isFocused)
                .onTapGesture { onFocus() }
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isFocused ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
                        .background(isFocused ? Color.accentColor.opacity(0.04) : Color.clear)
                        .cornerRadius(6)
                )
        }
        .padding(.vertical, 2)
        .opacity(isZoomed && !isFocused ? 0.25 : 1)
        .scaleEffect(isZoomed && isFocused ? 1.02 : 1)
        .animation(.easeInOut(duration: 0.2), value: isZoomed)
    }
}

// MARK: - 左侧操作栏

private struct BlockLeftHandle: View {
    let block: ContentBlock
    let isFocused: Bool
    let onZoom: () -> Void
    let onDelete: () -> Void
    let onConvert: (BlockType) -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: block.type.icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            if isFocused {
                Menu {
                    ForEach(BlockType.allCases, id: \.self) { type in
                        Button(type.rawValue) {
                            onConvert(type)
                        }
                    }
                    Divider()
                    Button("聚焦此块") { onZoom() }
                    Button("删除", role: .destructive) { onDelete() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption2)
                        .frame(width: 20, height: 20)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .frame(width: 24)
    }
}

// MARK: - 块内容视图

private struct BlockContentView: View {
    @Binding var block: ContentBlock
    var isFocused: Bool
    
    var body: some View {
        switch block.type {
        case .paragraph:
            BlockParagraphEditor(block: $block, isFocused: isFocused)
        case .heading1, .heading2, .heading3, .heading4, .heading5, .heading6:
            BlockHeadingEditor(block: $block, isFocused: isFocused)
        case .unorderedList, .orderedList:
            BlockListEditor(block: $block, isFocused: isFocused)
        case .quote:
            BlockQuoteEditor(block: $block, isFocused: isFocused)
        case .code:
            BlockCodeEditor(block: $block, isFocused: isFocused)
        case .divider:
            BlockDividerView()
        }
    }
}

// MARK: - 段落块

struct BlockParagraphEditor: View {
    @Binding var block: ContentBlock
    var isFocused: Bool
    
    var body: some View {
        TextField("", text: $block.content, axis: .vertical)
            .font(.system(size: 16))
            .lineSpacing(6)
            .textFieldStyle(.plain)
            .scrollContentBackground(.hidden)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 标题块

struct BlockHeadingEditor: View {
    @Binding var block: ContentBlock
    var isFocused: Bool
    
    var body: some View {
        TextField("", text: $block.content, axis: .vertical)
            .font(.system(size: block.type.fontSize, weight: .bold))
            .lineSpacing(4)
            .textFieldStyle(.plain)
            .scrollContentBackground(.hidden)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 列表块

struct BlockListEditor: View {
    @Binding var block: ContentBlock
    var isFocused: Bool
    
    private var prefix: String {
        block.type == .unorderedList ? "• " : "1. "
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text(prefix)
                .foregroundStyle(.secondary)
                .font(.system(size: 16))
            TextField("", text: $block.content, axis: .vertical)
                .font(.system(size: 16))
                .lineSpacing(6)
                .textFieldStyle(.plain)
                .scrollContentBackground(.hidden)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 引用块

struct BlockQuoteEditor: View {
    @Binding var block: ContentBlock
    var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 3)
            TextField("", text: $block.content, axis: .vertical)
                .font(.system(size: 16))
                .italic()
                .foregroundStyle(.secondary)
                .lineSpacing(6)
                .textFieldStyle(.plain)
                .scrollContentBackground(.hidden)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 代码块

struct BlockCodeEditor: View {
    @Binding var block: ContentBlock
    var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let lang = block.language, !lang.isEmpty {
                Text(lang)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            }
            TextField("", text: $block.content, axis: .vertical)
                .font(.system(.body, design: .monospaced))
                .lineSpacing(4)
                .textFieldStyle(.plain)
                .scrollContentBackground(.hidden)
                .fixedSize(horizontal: false, vertical: true)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
        }
    }
}

// MARK: - 分隔线块

struct BlockDividerView: View {
    var body: some View {
        Divider()
            .padding(.vertical, 8)
    }
}

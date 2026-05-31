import SwiftUI

/// 块大纲视图，基于 heading 块生成可导航的目录树。
struct BlockOutlineView: View {
    let blocks: [ContentBlock]
    @Binding var selectedBlockID: UUID?
    
    /// 过滤出所有标题块及其层级
    private var headings: [(block: ContentBlock, level: Int)] {
        blocks.compactMap { block in
            guard let level = block.type.headingLevel else { return nil }
            return (block, level)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("大纲")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(headings, id: \.block.id) { item in
                        Button {
                            selectedBlockID = item.block.id
                        } label: {
                            Text(item.block.content.isEmpty ? "无标题" : item.block.content)
                                .font(.system(size: CGFloat(16 - item.level)))
                                .lineLimit(1)
                                .padding(.vertical, 4)
                                .padding(.leading, CGFloat((item.level - 1) * 12))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .background(selectedBlockID == item.block.id ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            
            Spacer()
        }
        .frame(width: 200)
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(.secondarySystemBackground))
        #endif
    }
}

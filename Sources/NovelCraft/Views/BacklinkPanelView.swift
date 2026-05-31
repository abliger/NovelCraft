import SwiftUI
import SwiftData

/// 反向链接面板，展示引用当前内容块的所有文档。
struct BacklinkPanelView: View {
    @Environment(\.modelContext) private var modelContext
    
    let blockID: UUID
    let blockTitle: String
    
    @State private var backlinks: [ContentBlockRef] = []
    @State private var forwardRefs: [ContentBlockRef] = []
    @State private var selectedTab: RefPanelTab = .backlinks
    
    enum RefPanelTab: String, CaseIterable {
        case backlinks = "反向链接"
        case forward = "正向链接"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标签切换
            Picker("", selection: $selectedTab) {
                ForEach(RefPanelTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            // 列表
            List {
                switch selectedTab {
                case .backlinks:
                    if backlinks.isEmpty {
                        Section {
                            Text("暂无内容引用此块")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        }
                    } else {
                        Section(header: Text("共 \(backlinks.count) 条引用")) {
                            ForEach(backlinks, id: \.id) { ref in
                                RefRow(ref: ref, isSource: true)
                            }
                        }
                    }
                case .forward:
                    if forwardRefs.isEmpty {
                        Section {
                            Text("此块尚未引用其他内容")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        }
                    } else {
                        Section(header: Text("共 \(forwardRefs.count) 条引用")) {
                            ForEach(forwardRefs, id: \.id) { ref in
                                RefRow(ref: ref, isSource: false)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .task(id: blockID) {
            await loadRefs()
        }
        .onChange(of: blockID) { _, _ in
            Task { await loadRefs() }
        }
    }
    
    @MainActor
    private func loadRefs() async {
        backlinks = BlockRefEngine.backlinks(to: blockID, context: modelContext)
        forwardRefs = BlockRefEngine.forwardRefs(from: blockID, context: modelContext)
    }
}

/// 单条引用记录的展示行。
private struct RefRow: View {
    @Environment(\.modelContext) private var modelContext
    
    let ref: ContentBlockRef
    /// true 表示展示引用方（反向链接），false 表示展示被引用方（正向链接）
    let isSource: Bool
    
    @State private var targetTitle: String = ""
    @State private var targetType: BlockType = .chapter
    
    private var displayID: UUID {
        isSource ? ref.sourceBlockID : ref.targetBlockID
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: targetType.icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(targetTitle.isEmpty ? "未命名" : targetTitle)
                    .font(.callout)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(targetType.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if !ref.anchorText.isEmpty {
                        Text("· \(ref.anchorText)")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                }
            }
            
            Spacer()
            
            Text(ref.refTypeEnum.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ref.refTypeEnum == .embed ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                .foregroundStyle(ref.refTypeEnum == .embed ? .blue : .purple)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
        .task {
            await resolveTarget()
        }
    }
    
    @MainActor
    private func resolveTarget() async {
        if let meta = BlockRefEngine.resolveBlock(blockID: displayID, context: modelContext) {
            targetTitle = meta.title
            targetType = meta.type
        } else {
            targetTitle = displayID.uuidString.prefix(8) + "…"
        }
    }
}

import Foundation
import SwiftData

/// 内容块引用引擎
///
/// 负责扫描文本中的双向链接语法、同步数据库引用记录，以及提供反向链接查询。
enum BlockRefEngine {
    
    // MARK: - 正则表达式
    
    /// 匹配 ((id)) 或 ((id "锚文本"))
    static let blockRefPattern: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\(\(([^)]+)\)\)"#,
        options: []
    )
    
    /// 匹配 {{id}}
    static let blockEmbedPattern: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\{\{([^}]+)\}\}"#,
        options: []
    )
    
    // MARK: - 扫描引用
    
    /// 扫描文本中的所有块引用与嵌入，返回结构化结果。
    ///
    /// - 引用格式：`((UUID))` 或 `((UUID "锚文本"))`
    /// - 嵌入格式：`{{UUID}}`
    static func scanRefs(in text: String) -> [(targetID: String, anchor: String?, isEmbed: Bool)] {
        var results: [(targetID: String, anchor: String?, isEmbed: Bool)] = []
        let nsRange = NSRange(text.startIndex..., in: text)
        
        // 扫描 ((...))
        if let pattern = blockRefPattern {
            let refMatches = pattern.matches(in: text, options: [], range: nsRange)
            for match in refMatches {
                guard let range = Range(match.range(at: 1), in: text) else { continue }
                let content = String(text[range]).trimmingCharacters(in: .whitespaces)
                let (id, anchor) = parseRefContent(content)
                results.append((targetID: id, anchor: anchor, isEmbed: false))
            }
        }
        
        // 扫描 {{...}}
        if let pattern = blockEmbedPattern {
            let embedMatches = pattern.matches(in: text, options: [], range: nsRange)
            for match in embedMatches {
                guard let range = Range(match.range(at: 1), in: text) else { continue }
                let id = String(text[range]).trimmingCharacters(in: .whitespaces)
                results.append((targetID: id, anchor: nil, isEmbed: true))
            }
        }
        
        return results
    }
    
    /// 解析 ((...)) 内部的内容，分离 ID 与锚文本。
    ///
    /// 支持的格式：
    /// - `550e8400-e29b-41d4-a716-446655440000`
    /// - `550e8400-e29b-41d4-a716-446655440000 "锚文本"`
    private static func parseRefContent(_ content: String) -> (id: String, anchor: String?) {
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        
        // 查找第一个引号，之后的内容作为锚文本
        if let quoteIndex = trimmed.firstIndex(of: "\"") {
            let idPart = String(trimmed[..<quoteIndex]).trimmingCharacters(in: .whitespaces)
            let afterQuote = trimmed.index(after: quoteIndex)
            let remaining = String(trimmed[afterQuote...])
            if let lastQuote = remaining.lastIndex(of: "\"") {
                let anchor = String(remaining[..<lastQuote])
                return (idPart, anchor.isEmpty ? nil : anchor)
            }
            return (idPart, nil)
        }
        
        return (trimmed, nil)
    }
    
    // MARK: - 数据库同步
    
    /// 同步指定内容块的引用记录。
    ///
    /// 解析 `content` 中的引用语法，删除旧的引用记录，并插入新的记录。
    static func syncRefs(sourceBlockID: UUID, content: String, context: ModelContext) {
        let refs = scanRefs(in: content)
        
        // 删除旧的引用记录
        let oldPredicate = #Predicate<ContentBlockRef> {
            $0.sourceBlockID == sourceBlockID
        }
        let oldDescriptor = FetchDescriptor<ContentBlockRef>(predicate: oldPredicate)
        do {
            let oldRefs = try context.fetch(oldDescriptor)
            for oldRef in oldRefs {
                context.delete(oldRef)
            }
        } catch {
            print("删除旧引用记录失败: \(error)")
        }
        
        // 插入新的引用记录
        for ref in refs {
            guard UUID(uuidString: ref.targetID) != nil else {
                // ID 格式无效，跳过
                continue
            }
            let newRef = ContentBlockRef(
                sourceBlockID: sourceBlockID,
                targetBlockID: UUID(uuidString: ref.targetID)!,
                anchorText: ref.anchor ?? "",
                refType: ref.isEmbed ? RefType.embed.rawValue : RefType.ref.rawValue
            )
            context.insert(newRef)
        }
    }
    
    // MARK: - 反向链接查询
    
    /// 查询引用指定内容块的所有记录。
    static func backlinks(to targetBlockID: UUID, context: ModelContext) -> [ContentBlockRef] {
        let predicate = #Predicate<ContentBlockRef> {
            $0.targetBlockID == targetBlockID
        }
        let descriptor = FetchDescriptor<ContentBlockRef>(predicate: predicate)
        do {
            return try context.fetch(descriptor)
        } catch {
            print("查询反向链接失败: \(error)")
            return []
        }
    }
    
    /// 查询指定内容块引用的所有记录（正向链接）。
    static func forwardRefs(from sourceBlockID: UUID, context: ModelContext) -> [ContentBlockRef] {
        let predicate = #Predicate<ContentBlockRef> {
            $0.sourceBlockID == sourceBlockID
        }
        let descriptor = FetchDescriptor<ContentBlockRef>(predicate: predicate)
        do {
            return try context.fetch(descriptor)
        } catch {
            print("查询正向链接失败: \(error)")
            return []
        }
    }
    
    // MARK: - 引用清理
    
    /// 删除与指定内容块 ID 相关的所有引用记录（正向和反向）。
    ///
    /// 当删除章节、角色、便签等内容块时，应调用此方法以避免产生悬挂引用。
    static func deleteRefs(for blockID: UUID, context: ModelContext) {
        // 删除所有 sourceBlockID 等于 blockID 的正向引用
        let sourcePredicate = #Predicate<ContentBlockRef> {
            $0.sourceBlockID == blockID
        }
        do {
            let sourceRefs = try context.fetch(FetchDescriptor<ContentBlockRef>(predicate: sourcePredicate))
            for ref in sourceRefs { context.delete(ref) }
        } catch {
            print("删除正向引用记录失败: \(error)")
        }
        
        // 删除所有 targetBlockID 等于 blockID 的反向引用
        let targetPredicate = #Predicate<ContentBlockRef> {
            $0.targetBlockID == blockID
        }
        do {
            let targetRefs = try context.fetch(FetchDescriptor<ContentBlockRef>(predicate: targetPredicate))
            for ref in targetRefs { context.delete(ref) }
        } catch {
            print("删除反向引用记录失败: \(error)")
        }
    }
    
    // MARK: - 内容块标题查询
    
    /// 尝试根据 ID 在项目上下文中查找内容块的标题。
    ///
    /// 依次查询 Chapter、Note、StoryScene、OutlineNode、WorldSetting、Character。
    static func resolveBlockTitle(blockID: UUID, context: ModelContext) -> String? {
        // Chapter
        if let chapter = try? context.fetch(FetchDescriptor<Chapter>(predicate: #Predicate { $0.id == blockID })).first {
            return chapter.title
        }
        // Note
        if let note = try? context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.id == blockID })).first {
            return note.title.isEmpty ? "便签" : note.title
        }
        // StoryScene
        if let scene = try? context.fetch(FetchDescriptor<StoryScene>(predicate: #Predicate { $0.id == blockID })).first {
            return scene.title
        }
        // OutlineNode
        if let node = try? context.fetch(FetchDescriptor<OutlineNode>(predicate: #Predicate { $0.id == blockID })).first {
            return node.title.isEmpty ? "大纲卡片" : node.title
        }
        // WorldSetting
        if let ws = try? context.fetch(FetchDescriptor<WorldSetting>(predicate: #Predicate { $0.id == blockID })).first {
            return ws.title
        }
        // Character
        if let character = try? context.fetch(FetchDescriptor<Character>(predicate: #Predicate { $0.id == blockID })).first {
            return character.name
        }
        return nil
    }
    
    /// 根据 ID 查找任意内容块，返回可用于导航的元数据。
    static func resolveBlock(blockID: UUID, context: ModelContext) -> BlockMeta? {
        // Chapter
        if let chapter = try? context.fetch(FetchDescriptor<Chapter>(predicate: #Predicate { $0.id == blockID })).first {
            return BlockMeta(id: blockID, title: chapter.title, type: .chapter)
        }
        // Note
        if let note = try? context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.id == blockID })).first {
            return BlockMeta(id: blockID, title: note.title.isEmpty ? "便签" : note.title, type: .note)
        }
        // StoryScene
        if let scene = try? context.fetch(FetchDescriptor<StoryScene>(predicate: #Predicate { $0.id == blockID })).first {
            return BlockMeta(id: blockID, title: scene.title, type: .scene)
        }
        // OutlineNode
        if let node = try? context.fetch(FetchDescriptor<OutlineNode>(predicate: #Predicate { $0.id == blockID })).first {
            return BlockMeta(id: blockID, title: node.title.isEmpty ? "大纲卡片" : node.title, type: .outline)
        }
        // WorldSetting
        if let ws = try? context.fetch(FetchDescriptor<WorldSetting>(predicate: #Predicate { $0.id == blockID })).first {
            return BlockMeta(id: blockID, title: ws.title, type: .worldSetting)
        }
        // Character
        if let character = try? context.fetch(FetchDescriptor<Character>(predicate: #Predicate { $0.id == blockID })).first {
            return BlockMeta(id: blockID, title: character.name, type: .character)
        }
        return nil
    }
}

// MARK: - 内容块元数据

/// 内容块实体类型枚举
enum EntityBlockType: String, CaseIterable {
    case volume = "卷"
    case chapter = "章节"
    case note = "便签"
    case scene = "场景"
    case outline = "大纲"
    case worldSetting = "世界观"
    case character = "角色"
    
    var icon: String {
        switch self {
        case .volume: return "folder"
        case .chapter: return "doc.text"
        case .note: return "note.text"
        case .scene: return "film"
        case .outline: return "diagram.project"
        case .worldSetting: return "globe"
        case .character: return "person"
        }
    }
}

/// 内容块元数据，用于列表展示与导航。
struct BlockMeta: Identifiable {
    let id: UUID
    let title: String
    let type: EntityBlockType
}

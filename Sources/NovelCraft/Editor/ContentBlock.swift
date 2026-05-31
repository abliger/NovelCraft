import Foundation

/// 内容块类型枚举
enum BlockType: String, Equatable, CaseIterable {
    case paragraph = "段落"
    case heading1 = "标题 1"
    case heading2 = "标题 2"
    case heading3 = "标题 3"
    case heading4 = "标题 4"
    case heading5 = "标题 5"
    case heading6 = "标题 6"
    case unorderedList = "无序列表"
    case orderedList = "有序列表"
    case quote = "引用"
    case code = "代码块"
    case divider = "分隔线"
    
    var icon: String {
        switch self {
        case .paragraph: return "text.alignleft"
        case .heading1: return "textformat.size.larger"
        case .heading2: return "textformat.size"
        case .heading3, .heading4, .heading5, .heading6: return "textformat.size.smaller"
        case .unorderedList: return "list.bullet"
        case .orderedList: return "list.number"
        case .quote: return "text.quote"
        case .code: return "curlybraces"
        case .divider: return "minus"
        }
    }
    
    var fontSize: CGFloat {
        switch self {
        case .heading1: return 28
        case .heading2: return 24
        case .heading3: return 20
        case .heading4: return 18
        case .heading5: return 16
        case .heading6: return 14
        default: return 16
        }
    }
    
    var isHeading: Bool {
        switch self {
        case .heading1, .heading2, .heading3, .heading4, .heading5, .heading6:
            return true
        default:
            return false
        }
    }
    
    var headingLevel: Int? {
        switch self {
        case .heading1: return 1
        case .heading2: return 2
        case .heading3: return 3
        case .heading4: return 4
        case .heading5: return 5
        case .heading6: return 6
        default: return nil
        }
    }
}

/// 内容块模型，代表编辑器中的一个独立编辑单元
struct ContentBlock: Identifiable, Equatable {
    let id: UUID
    var type: BlockType
    var content: String
    var language: String?
    var isFolded: Bool = false
    
    init(id: UUID = UUID(), type: BlockType, content: String, language: String? = nil, isFolded: Bool = false) {
        self.id = id
        self.type = type
        self.content = content
        self.language = language
        self.isFolded = isFolded
    }
}

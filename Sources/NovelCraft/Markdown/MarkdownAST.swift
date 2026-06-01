import Foundation

/// Markdown 抽象语法树节点
///
/// 采用间接枚举（indirect enum）表示树形结构，覆盖小说写作常用的 Markdown 元素。
indirect enum MDNode: Equatable {
    /// 文档根节点
    case document(children: [MDNode])
    /// 标题，level: 1–6
    case heading(level: Int, children: [MDNode])
    /// 段落
    case paragraph(children: [MDNode])
    /// 纯文本叶子节点
    case text(String)
    /// 粗体
    case bold(children: [MDNode])
    /// 斜体
    case italic(children: [MDNode])
    /// 删除线
    case strikethrough(children: [MDNode])
    /// 围栏代码块
    case codeBlock(language: String?, content: String)
    /// 行内代码
    case inlineCode(content: String)
    /// 超链接
    case link(url: String, children: [MDNode])
    /// 图片
    case image(alt: String, url: String)
    /// 有序列表
    case orderedList(items: [MDNode])
    /// 无序列表
    case unorderedList(items: [MDNode])
    /// 列表项
    case listItem(children: [MDNode])
    /// 引用块
    case blockQuote(children: [MDNode])
    /// 分隔线
    case horizontalRule
    /// 硬换行（行尾两个空格后回车）
    case lineBreak
    /// 软换行（普通回车）
    case softBreak
    /// 块引用 ((id "锚文本"))
    case blockRef(id: String, anchor: String?)
    /// 块嵌入 {{id}}
    case blockEmbed(id: String)
}

extension MDNode {
    /// 返回节点的纯文本内容（用于字数统计或搜索）
    var plainText: String {
        switch self {
        case .document(let children), .heading(_, let children),
             .paragraph(let children), .bold(let children),
             .italic(let children), .strikethrough(let children),
             .link(_, let children), .blockQuote(let children),
             .listItem(let children):
            return children.map(\.plainText).joined()
        case .orderedList(let items), .unorderedList(let items):
            return items.map(\.plainText).joined()
        case .text(let content):
            return content
        case .codeBlock(_, let content), .inlineCode(let content):
            return content
        case .image(let alt, _):
            return alt
        case .horizontalRule, .lineBreak, .softBreak:
            return ""
        case .blockRef(_, let anchor):
            return anchor ?? ""
        case .blockEmbed(_):
            return ""
        }
    }
}

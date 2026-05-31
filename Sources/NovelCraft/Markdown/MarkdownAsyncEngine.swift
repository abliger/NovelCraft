import Foundation

/// Markdown 异步解析引擎
///
/// 基于 Swift Concurrency 实现多线程异步解析，适合处理长文档或实时输入预览。
/// 内部使用 `actor` 隔离状态，避免竞态条件；新请求会自动取消旧任务。
actor MarkdownAsyncEngine {
    private var currentTask: Task<MDNode, Error>?
    private var generation: UInt = 0

    /// 解析 Markdown 文本，返回 AST 根节点（`.document`）
    ///
    /// - Parameter text: Markdown 原始文本（可以是文件内容或正在输入的文本）
    /// - Returns: 解析后的抽象语法树
    func parse(_ text: String) async -> MDNode {
        currentTask?.cancel()

        let task = Task.detached(priority: .userInitiated) { () -> MDNode in
            // 阶段一：块级解析（基于行）
            var blockParser = MarkdownBlockParser(text: text)
            let ast = blockParser.parse()

            // 检查是否已被更新的请求取代
            if Task.isCancelled {
                throw CancellationError()
            }

            return ast
        }

        currentTask = task

        do {
            return try await task.value
        } catch is CancellationError {
            // 被取消时返回空文档，调用方应忽略此结果
            return .document(children: [])
        } catch {
            // 解析异常时降级为空文档，避免崩溃
            return .document(children: [])
        }
    }

    /// 异步解析并将 AST 渲染为 `AttributedString`，用于编辑器预览
    func renderAttributedString(_ text: String) async -> AttributedString {
        let ast = await parse(text)
        // 渲染在主线程进行（AttributedString 操作轻量）
        return MarkdownRenderer.render(ast)
    }

    /// 批量解析多个 Markdown 文件（例如导出时的全文解析）
    func parseFiles(_ contents: [String]) async -> [MDNode] {
        await withTaskGroup(of: MDNode.self) { group in
            for content in contents {
                group.addTask {
                    var parser = MarkdownBlockParser(text: content)
                    return parser.parse()
                }
            }

            var results: [MDNode] = []
            for await node in group {
                results.append(node)
            }
            return results
        }
    }
}

// MARK: - 便捷单例接口

/// 全局 Markdown 解析入口，提供同步与异步两种调用方式
enum MarkdownParser {
    /// 同步解析，适合短文本或初始化场景
    static func parse(_ text: String) -> MDNode {
        var parser = MarkdownBlockParser(text: text)
        return parser.parse()
    }

    /// 同步渲染为 AttributedString（兼容旧接口）
    static func attributedString(from text: String) -> AttributedString {
        let ast = parse(text)
        return MarkdownRenderer.render(ast)
    }

    /// 异步解析引擎单例（延迟初始化）
    private static let asyncEngine = MarkdownAsyncEngine()

    /// 异步解析文本
    static func parseAsync(_ text: String) async -> MDNode {
        await asyncEngine.parse(text)
    }

    /// 异步渲染为 AttributedString
    static func attributedStringAsync(from text: String) async -> AttributedString {
        await asyncEngine.renderAttributedString(text)
    }
}

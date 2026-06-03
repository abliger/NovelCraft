import Foundation

/// AI 生成策略协议。各品牌通过实现此协议接入统一接口。
protocol AIGenerationStrategy: Sendable {
    /// 品牌标识
    var id: String { get }
    /// 品牌显示名称
    var displayName: String { get }
    /// 默认模型名称
    var defaultModel: String { get }
    /// API 基础地址
    var baseURL: String { get }
    
    /// 发送生成请求。
    /// - Parameters:
    ///   - apiKey: API 密钥
    ///   - prompt: 用户提示词
    ///   - model: 使用的模型名称
    /// - Returns: AI 返回的文本内容
    func generate(apiKey: String, prompt: String, model: String) async throws -> String
}

/// AI 请求通用的网络错误。
enum AIGenerationError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 API 地址"
        case .invalidResponse: return "API 返回了无法解析的响应"
        case .apiError(let msg): return "API 错误: \(msg)"
        case .networkError(let err): return "网络错误: \(err.localizedDescription)"
        }
    }
}

/// AI 生成请求的统一消息结构。
struct AIMessage: Codable {
    let role: String
    let content: String
}

/// DeepSeek / OpenAI 兼容格式的请求体。
struct AIChatRequest: Codable {
    let model: String
    let messages: [AIMessage]
    let temperature: Double?
    
    init(model: String, messages: [AIMessage], temperature: Double? = 0.7) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
    }
}

/// DeepSeek / OpenAI 兼容格式的响应体。
struct AIChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String?
        }
        let message: Message
    }
    struct ErrorDetail: Codable {
        let message: String
    }
    let choices: [Choice]?
    let error: ErrorDetail?
}

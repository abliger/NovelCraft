import Foundation

/// DeepSeek AI 生成策略实现。
struct DeepSeekStrategy: AIGenerationStrategy {
    let id = "deepseek"
    let displayName = "DeepSeek"
    let defaultModel = "deepseek-chat"
    let baseURL = "https://api.deepseek.com/v1/chat/completions"
    
    func generate(apiKey: String, prompt: String, model: String) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw AIGenerationError.invalidURL
        }
        
        let requestBody = AIChatRequest(
            model: model,
            messages: [
                AIMessage(role: "system", content: "你是一位专业的小说创作助手，擅长根据用户需求生成高质量的中文小说内容。请直接输出正文内容，不要添加额外的解释或标记。"),
                AIMessage(role: "user", content: prompt)
            ],
            temperature: 0.7
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIGenerationError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            // 尝试解析错误信息
            if let errorResponse = try? JSONDecoder().decode(AIChatResponse.self, from: data),
               let errorMsg = errorResponse.error?.message {
                throw AIGenerationError.apiError(errorMsg)
            }
            throw AIGenerationError.invalidResponse
        }
        
        let decoded = try JSONDecoder().decode(AIChatResponse.self, from: data)
        guard let content = decoded.choices?.first?.message.content else {
            throw AIGenerationError.invalidResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

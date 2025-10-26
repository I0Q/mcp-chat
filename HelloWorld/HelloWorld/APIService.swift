//
//  APIService.swift
//  HelloWorld
//
//  Created by Acacio Santana on 10/26/25.
//

import Foundation

class APIService {
    static let shared = APIService()
    
    private init() {}
    
    func sendMessage(message: String, chatHistory: [ChatMessage]) async throws -> String {
        let settings = SettingsManager.shared
        let urlString = "\(settings.serverURL)/v1/chat/completions"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        // Convert chat history to API format
        var messages: [[String: Any]] = chatHistory.map { msg in
            ["role": msg.role, "content": msg.content] as [String: Any]
        }
        
        var requestBody: [String: Any] = [
            "model": settings.selectedModel,
            "messages": messages
        ]
        
        // Add thinking mode if enabled
        if settings.thinkingEnabled {
            let modeMap: [String: String] = [
                "low": "concise",
                "medium": "balanced",
                "high": "expressive"
            ]
            requestBody["mode"] = modeMap[settings.thinkingEffort] ?? "balanced"
        }
        
        // If MCP is enabled, add tools to the request
        if settings.mcpEnabled {
            let tools = MCPService.shared.getAvailableTools()
            if !tools.isEmpty {
                requestBody["tools"] = tools.map { tool in
                    [
                        "type": "function",
                        "function": [
                            "name": tool.name,
                            "description": tool.description ?? ""
                        ]
                    ] as [String: Any]
                }
            }
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let responseData = try decoder.decode(ChatCompletionResponse.self, from: data)
        
        // Check if the model wants to use a tool
        if let toolCall = responseData.choices.first?.message.toolCalls?.first {
            // Execute the tool call
            let toolResult = try await executeToolCall(toolCall)
            
            // Add assistant's tool call and tool result to messages
            let toolCallDict: [String: Any] = [
                "id": toolCall.id,
                "type": "function",
                "function": [
                    "name": toolCall.function.name,
                    "arguments": toolCall.function.arguments
                ]
            ]
            
            var assistantMessage: [String: Any] = [
                "role": "assistant",
                "tool_calls": [toolCallDict]
            ]
            messages.append(assistantMessage)
            
            var toolMessage: [String: Any] = [
                "role": "tool",
                "name": toolCall.function.name,
                "content": toolResult,
                "tool_call_id": toolCall.id
            ]
            messages.append(toolMessage)
            
            // Make a second request with tool result
            requestBody["messages"] = messages
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (secondData, secondResponse) = try await URLSession.shared.data(for: request)
            
            guard let secondHttpResponse = secondResponse as? HTTPURLResponse,
                  (200...299).contains(secondHttpResponse.statusCode) else {
                throw APIError.httpError((secondResponse as? HTTPURLResponse)?.statusCode ?? 500)
            }
            
            let secondResponseData = try decoder.decode(ChatCompletionResponse.self, from: secondData)
            
            // Check if second response has tool calls (continue tool calling loop)
            if let secondToolCall = secondResponseData.choices.first?.message.toolCalls?.first {
                // Execute second tool call and make another request
                let secondToolResult = try await executeToolCall(secondToolCall)
                
                messages.append([
                    "role": "assistant",
                    "tool_calls": [[
                        "id": secondToolCall.id,
                        "type": "function",
                        "function": [
                            "name": secondToolCall.function.name,
                            "arguments": secondToolCall.function.arguments
                        ] as [String: Any]
                    ]]
                ])
                
                messages.append([
                    "role": "tool",
                    "name": secondToolCall.function.name,
                    "content": secondToolResult,
                    "tool_call_id": secondToolCall.id
                ])
                
                requestBody["messages"] = messages
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                
                let (thirdData, thirdResponse) = try await URLSession.shared.data(for: request)
                
                guard let thirdHttpResponse = thirdResponse as? HTTPURLResponse,
                      (200...299).contains(thirdHttpResponse.statusCode) else {
                    throw APIError.httpError((thirdResponse as? HTTPURLResponse)?.statusCode ?? 500)
                }
                
                let thirdResponseData = try decoder.decode(ChatCompletionResponse.self, from: thirdData)
                return thirdResponseData.choices.first?.message.content ?? ""
            }
            
            return secondResponseData.choices.first?.message.content ?? ""
        }
        
        return responseData.choices.first?.message.content ?? ""
    }
    
    private func executeToolCall(_ toolCall: ChatCompletionResponse.ToolCall) async throws -> String {
        let arguments = try JSONSerialization.jsonObject(with: toolCall.function.arguments.data(using: .utf8)!) as? [String: Any] ?? [:]
        return try await MCPService.shared.callTool(name: toolCall.function.name, arguments: arguments)
    }
    
    enum APIError: LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(Int)
        case decodingError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response from server"
            case .httpError(let code):
                return "HTTP Error: \(code)"
            case .decodingError:
                return "Failed to decode response"
            }
        }
    }
}

struct ChatCompletionResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String?
        let toolCalls: [ToolCall]?
        
        enum CodingKeys: String, CodingKey {
            case content
            case toolCalls = "tool_calls"
        }
    }
    
    struct ToolCall: Codable {
        let id: String
        let type: String
        let function: Function
        
        struct Function: Codable {
            let name: String
            let arguments: String
        }
    }
}


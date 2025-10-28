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
    
    func sendMessage(message: String, chatHistory: [ChatMessage], onThinking: ((String?) -> Void)? = nil, onToolCall: ((String?) -> Void)? = nil, onThinkingTokens: ((String) -> Void)? = nil, onMCPToolInfo: ((String) -> Void)? = nil) async throws -> String {
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
        
        // Note: Streaming disabled for now - will show thinking tokens from final response
        
        // Add thinking mode if enabled
        if settings.thinkingEnabled {
            let modeMap: [String: String] = [
                "low": "concise",
                "medium": "balanced",
                "high": "expressive"
            ]
            let mode = modeMap[settings.thinkingEffort] ?? "balanced"
            requestBody["mode"] = mode
            print("🧠 Thinking mode enabled: \(settings.thinkingEffort) -> \(mode)")
        } else {
            print("❌ Thinking mode is disabled")
        }
        
        // If MCP is enabled, add tools from all enabled servers to the request
        if settings.mcpEnabled {
            var allTools: [MCPTool] = []
            
            // Fetch tools from all enabled MCP servers
            for serverConfig in settings.getEnabledMCPServers() {
                do {
                    let tools = try await MCPClient.shared.fetchTools(for: serverConfig)
                    allTools.append(contentsOf: tools)
                    print("📦 Fetched \(tools.count) tools from \(serverConfig.name)")
                } catch {
                    print("⚠️ Could not fetch tools from \(serverConfig.name): \(error)")
                }
            }
            
            if !allTools.isEmpty {
                requestBody["tools"] = allTools.map { tool in
                    var function: [String: Any] = [
                        "name": tool.name,
                        "description": tool.description ?? ""
                    ]
                    
                    // Add parameters (input schema) if available
                    if let inputSchema = tool.inputSchema {
                        function["parameters"] = inputSchema
                    }
                    
                    return [
                        "type": "function",
                        "function": function
                    ] as [String: Any]
                }
                print("🔧 Sending \(allTools.count) total tools to LLM")
            }
        }
        
        // Show initial thinking message
        await MainActor.run {
            onThinking?("Processing your message...")
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
        
        // Extract and display thinking tokens if present
        if let thinking = responseData.choices.first?.message.thinking {
            print("🧠 Thinking tokens received: \(thinking)")
            await MainActor.run {
                onThinkingTokens?(thinking)
            }
        } else {
            print("❌ No thinking tokens in response")
        }
        
        // Check if the model wants to use a tool
        if let toolCall = responseData.choices.first?.message.toolCalls?.first {
            // Show tool call in UI
            await MainActor.run {
                onToolCall?(toolCall.function.name)
                onThinking?("Executing tool: \(toolCall.function.name)...")
            }
            
            // Execute the tool call
            let toolResult = try await executeToolCall(toolCall)
            
            // Send tool info to callback if available
            if let toolInfo = capturedToolInfo {
                await MainActor.run {
                    onMCPToolInfo?(toolInfo)
                }
                capturedToolInfo = nil // Clear after sending
            }
            
            // Clear thinking message
            await MainActor.run {
                onThinking?(nil)
            }
            
            // Add assistant's tool call and tool result to messages
            let toolCallDict: [String: Any] = [
                "id": toolCall.id,
                "type": "function",
                "function": [
                    "name": toolCall.function.name,
                    "arguments": toolCall.function.arguments
                ]
            ]
            
            let assistantMessage: [String: Any] = [
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
                
                // Extract thinking from final response
                if let thinking = thirdResponseData.choices.first?.message.thinking {
                    await MainActor.run {
                        onThinkingTokens?(thinking)
                    }
                }
                
                return thirdResponseData.choices.first?.message.content ?? ""
            }
            
            return secondResponseData.choices.first?.message.content ?? ""
        }
        
        return responseData.choices.first?.message.content ?? ""
    }
    
    var capturedToolInfo: String? // Store tool info for the callback
    
    private func executeToolCall(_ toolCall: ChatCompletionResponse.ToolCall) async throws -> String {
        // Parse the arguments JSON string into a dictionary
        guard let jsonData = toolCall.function.arguments.data(using: .utf8) else {
            throw APIError.decodingError
        }
        
        let arguments = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] ?? [:]
        
        print("🔧 Executing tool: \(toolCall.function.name)")
        print("   Raw arguments JSON: \(toolCall.function.arguments)")
        print("   Parsed arguments: \(arguments)")
        
        // Format the tool call as JSON for debugging
        let toolCallDict: [String: Any] = [
            "name": toolCall.function.name,
            "arguments": arguments
        ]
        
        let toolCallJSON = try JSONSerialization.data(withJSONObject: toolCallDict, options: .prettyPrinted)
        let toolCallString = String(data: toolCallJSON, encoding: .utf8) ?? ""
        
        // Find which server has this tool and call it
        let settings = SettingsManager.shared
        var result = "Tool not found on any enabled server"
        
        for serverConfig in settings.getEnabledMCPServers() {
            do {
                // Check if this server has the tool by fetching its tools
                let tools = try await MCPClient.shared.fetchTools(for: serverConfig)
                if tools.contains(where: { $0.name == toolCall.function.name }) {
                    result = try await MCPClient.shared.callTool(name: toolCall.function.name, arguments: arguments, onServer: serverConfig)
                    print("✅ Tool \(toolCall.function.name) executed on \(serverConfig.name)")
                    break
                }
            } catch {
                print("⚠️ Error checking tools on \(serverConfig.name): \(error)")
            }
        }
        
        // Try to parse and format the result as JSON
        var formattedResult = result
        if let resultData = result.data(using: .utf8),
           let jsonObj = try? JSONSerialization.jsonObject(with: resultData),
           let prettyJSONData = try? JSONSerialization.data(withJSONObject: jsonObj, options: .prettyPrinted),
           let prettyJSONString = String(data: prettyJSONData, encoding: .utf8) {
            formattedResult = prettyJSONString
        }
        
        // Format the full tool info for display in UI
        let fullToolInfo = """
        MCP Tool Call:
        \(toolCallString)
        
        Result:
        \(formattedResult)
        """
        
        // Store for the callback
        capturedToolInfo = fullToolInfo
        
        print("📋 Full tool info:\n\(fullToolInfo)")
        
        return result
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
        let thinking: String?
        
        enum CodingKeys: String, CodingKey {
            case content
            case toolCalls = "tool_calls"
            case thinking = "reasoning"
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

struct StreamResponse: Codable {
    let choices: [StreamChoice]
    
    struct StreamChoice: Codable {
        let delta: StreamDelta?
    }
    
    struct StreamDelta: Codable {
        let content: String?
        let thinking: String?
        
        enum CodingKeys: String, CodingKey {
            case content
            case thinking = "reasoning"
        }
    }
}


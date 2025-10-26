//
//  MCPClient.swift
//  HelloWorld
//
//  MCP client using Server-Sent Events (SSE) for connecting to Home Assistant MCP server
//

import Foundation

class MCPClient {
    static let shared = MCPClient()
    
    private init() {}
    
    // Fetch tools from MCP server using SSE
    func fetchTools(sseURL: String, accessToken: String) async throws -> [MCPTool] {
        guard let url = URL(string: sseURL) else {
            throw MCPError.invalidURL
        }
        
        // MCP SSE uses a special URL format - we need to establish SSE connection
        // For Home Assistant MCP, tools are discovered through the Assist API intents
        // Let's use that instead
        guard let baseURL = URL(string: sseURL.replacingOccurrences(of: "/mcp_server/sse", with: "")) else {
            throw MCPError.invalidURL
        }
        
        let intentsURL = baseURL.appendingPathComponent("/api/assist_pipeline/conversation/intents")
        
        var request = URLRequest(url: intentsURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🔗 Fetching intents from Home Assistant Assist API")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MCPError.httpError(httpResponse?.statusCode ?? 500)
        }
        
        // Parse intents as tools
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let intents = json["intents"] as? [[String: Any]] {
            let tools = intents.compactMap { intent -> MCPTool? in
                guard let name = intent["name"] as? String else { return nil }
                let description = intent["description"] as? String
                return MCPTool(name: name, description: description)
            }
            
            print("✅ Fetched \(tools.count) tools from Assist API")
            return tools
        }
        
        throw MCPError.invalidResponse
    }
    
    // Call a tool using Home Assistant's conversation API
    func callTool(toolName: String, arguments: [String: Any], sseURL: String, accessToken: String) async throws -> String {
        guard let baseURL = URL(string: sseURL.replacingOccurrences(of: "/mcp_server/sse", with: "")) else {
            throw MCPError.invalidURL
        }
        
        // Use Home Assistant's conversation API to execute intents/tools
        let conversationURL = baseURL.appendingPathComponent("/api/conversation/process")
        
        // Build text command from tool name and arguments
        let argsString = arguments.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        let command = "\(toolName) \(argsString)"
        
        let requestBody: [String: Any] = [
            "agent_id": "conversation",
            "text": command
        ]
        
        var request = URLRequest(url: conversationURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🔧 Calling tool via conversation API: \(command)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        print("📡 Response Status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Error: \(errorBody)")
            throw MCPError.httpError(httpResponse.statusCode)
        }
        
        // Parse response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("📦 Response: \(json)")
            
            // Extract speech or response text
            if let speech = json["speech"] as? [String: Any],
               let plain = speech["plain"] as? [String: Any],
               let speechText = plain["speech"] as? String {
                return speechText
            }
            
            // Try alternative response formats
            if let message = json["message"] as? String {
                return message
            }
            
            if let responseText = json["response"] as? String {
                return responseText
            }
        }
        
        // If we can't parse, return success message
        return "Success"
    }
    
    enum MCPError: LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(Int)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response from MCP server"
            case .httpError(let code):
                return "HTTP Error: \(code)"
            }
        }
    }
}

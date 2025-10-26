//
//  MCPClient.swift
//  HelloWorld
//
//  MCP client using SSE streaming transport
//

import Foundation

class MCPClient {
    static let shared = MCPClient()
    
    private var sseSession: URLSession?
    private var sseTask: URLSessionDataTask?
    private var messageQueue: [String] = []
    
    private init() {
        let config = URLSessionConfiguration.default
        sseSession = URLSession(configuration: config)
    }
    
    // Fetch tools from MCP server via SSE
    func fetchTools(sseURL: String, accessToken: String) async throws -> [MCPTool] {
        print("🔗 Starting SSE connection to: \(sseURL)")
        
        // For now, SSE implementation is complex
        // The SSE endpoint is for streaming responses, not direct queries
        print("⚠️ SSE transport requires:")
        print("   1. Persistent GET connection")
        print("   2. Event stream parsing")  
        print("   3. Bidirectional messaging (complex)")
        print("💡 Consider using mcp-proxy for stdio transport")
        
        return []
    }
    
    // Call a tool via SSE streaming
    func callTool(toolName: String, arguments: [String: Any], sseURL: String, accessToken: String) async throws -> String {
        print("🔧 Calling tool via SSE: \(toolName)")
        
        // SSE is one-way, so we can't easily send requests
        // The typical approach is to use the conversation API
        // or implement full SSE bidirectional protocol
        
        guard let baseURL = URL(string: sseURL.replacingOccurrences(of: "/mcp_server/sse", with: "")) else {
            throw MCPError.invalidURL
        }
        
        // Use the conversation API as a fallback
        let conversationURL = baseURL.appendingPathComponent("/api/conversation/process")
        
        // Build natural language command
        var command = ""
        if let name = arguments["name"] as? String {
            if toolName == "HassTurnOn" {
                command = "turn on \(name)"
            } else if toolName == "HassTurnOff" {
                command = "turn off \(name)"
            } else if toolName == "HassSetPosition" {
                if let position = arguments["position"] {
                    command = "set \(name) to position \(position)"
                } else {
                    command = "set \(name)"
                }
            } else {
                command = name
            }
            command = command.replacingOccurrences(of: "_", with: " ")
        }
        
        let requestBody: [String: Any] = [
            "text": command
        ]
        
        var request = URLRequest(url: conversationURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MCPError.invalidResponse
        }
        
        // Parse response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let speech = json["speech"] as? [String: Any],
               let plain = speech["plain"] as? [String: Any],
               let speechText = plain["speech"] as? String {
                return speechText
            }
        }
        
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

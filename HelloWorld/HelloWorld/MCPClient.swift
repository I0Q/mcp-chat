//
//  MCPClient.swift
//  HelloWorld
//
//  MCP client that connects to remote MCP servers via SSE
//

import Foundation

class MCPClient {
    static let shared = MCPClient()
    
    private init() {}
    
    // Fetch tools from MCP server using proper MCP protocol
    // For remote SSE servers, we need to use the SSE transport properly
    func fetchTools(sseURL: String, accessToken: String) async throws -> [MCPTool] {
        guard let url = URL(string: sseURL) else {
            throw MCPError.invalidURL
        }
        
        print("🔗 Connecting to MCP server: \(sseURL)")
        
        // The SSE endpoint is for bidirectional communication
        // We need to send a POST request with JSON-RPC 2.0 message
        let requestId = UUID().uuidString
        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": requestId,
            "params": [:]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw MCPError.invalidURL
        }
        
        print("📤 Sending tools/list request: \(requestBody)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        print("📡 Response Status: \(httpResponse.statusCode)")
        
        // If we get 405, the SSE endpoint doesn't accept POST
        // This means we need mcp-proxy for proper bidirectional communication
        if httpResponse.statusCode == 405 {
            print("⚠️ SSE endpoint doesn't accept POST requests")
            print("ℹ️ This server requires SSE streaming transport")
            print("💡 For full MCP support, use mcp-proxy or implement SSE streaming client")
            return []
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            print("❌ Error: \(errorBody)")
            throw MCPError.httpError(httpResponse.statusCode)
        }
        
        // Parse JSON-RPC 2.0 response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MCPError.invalidResponse
        }
        
        print("📦 Response: \(json)")
        
        // Parse tools
        if let result = json["result"] as? [String: Any],
           let tools = result["tools"] as? [[String: Any]] {
            
            let parsedTools = tools.compactMap { toolDict -> MCPTool? in
                guard let name = toolDict["name"] as? String else { return nil }
                let description = toolDict["description"] as? String
                return MCPTool(name: name, description: description)
            }
            
            print("✅ Fetched \(parsedTools.count) tools from MCP server")
            return parsedTools
        }
        
        return []
    }
    
    // Call a tool using MCP protocol
    func callTool(toolName: String, arguments: [String: Any], sseURL: String, accessToken: String) async throws -> String {
        guard let url = URL(string: sseURL) else {
            throw MCPError.invalidURL
        }
        
        print("🔧 Calling MCP tool: \(toolName) with args: \(arguments)")
        
        let requestId = UUID().uuidString
        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "tools/call",
            "id": requestId,
            "params": [
                "name": toolName,
                "arguments": arguments
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw MCPError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        if httpResponse.statusCode == 405 {
            print("⚠️ SSE endpoint requires streaming transport")
            return "Tool execution requires SSE streaming implementation"
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            print("❌ Error: \(errorBody)")
            throw MCPError.httpError(httpResponse.statusCode)
        }
        
        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any] else {
            throw MCPError.invalidResponse
        }
        
        // Extract content
        if let content = result["content"] as? [[String: Any]] {
            let textItems = content.compactMap { item -> String? in
                if let type = item["type"] as? String, type == "text",
                   let text = item["text"] as? String {
                    return text
                }
                return nil
            }
            return textItems.joined(separator: "\n")
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

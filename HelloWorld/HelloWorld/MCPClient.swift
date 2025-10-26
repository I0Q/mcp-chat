//
//  MCPClient.swift
//  HelloWorld
//
//  MCP client with bidirectional SSE support
//

import Foundation

class MCPClient {
    static let shared = MCPClient()
    
    private var pendingRequests: [String: CheckedContinuation<[String: Any], Error>] = [:]
    
    private init() {}
    
    // Fetch tools from MCP server via SSE
    func fetchTools(sseURL: String, accessToken: String) async throws -> [MCPTool] {
        guard let url = URL(string: sseURL) else {
            throw MCPError.invalidURL
        }
        
        print("🔗 Fetching tools from MCP server: \(sseURL)")
        
        // Send POST request with JSON-RPC 2.0 message
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
        
        print("📤 Sending tools/list request")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        print("📡 Response Status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            print("❌ Error: \(errorBody)")
            
            // 405 means SSE endpoint needs different approach
            if httpResponse.statusCode == 405 {
                print("💡 SSE endpoint doesn't accept POST - needs SSE streaming connection")
            }
            
            throw MCPError.httpError(httpResponse.statusCode)
        }
        
        // Parse JSON-RPC response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MCPError.invalidResponse
        }
        
        print("📦 Response: \(json)")
        
        // Parse tools
        if let result = json["result"] as? String, result == "tools",
           let tools = json["tools"] as? [[String: Any]] {
            
            let parsedTools = tools.compactMap { toolDict -> MCPTool? in
                guard let name = toolDict["name"] as? String else { return nil }
                let description = toolDict["description"] as? String
                return MCPTool(name: name, description: description)
            }
            
            print("✅ Fetched \(parsedTools.count) tools")
            return parsedTools
        }
        
        // Try alternative response format
        if let result = json["result"] as? [String: Any],
           let tools = result["tools"] as? [[String: Any]] {
            let parsedTools = tools.compactMap { toolDict -> MCPTool? in
                guard let name = toolDict["name"] as? String else { return nil }
                let description = toolDict["description"] as? String
                return MCPTool(name: name, description: description)
            }
            
            print("✅ Fetched \(parsedTools.count) tools")
            return parsedTools
        }
        
        return []
    }
    
    // Call a tool via SSE with bidirectional communication
    func callTool(toolName: String, arguments: [String: Any], sseURL: String, accessToken: String) async throws -> String {
        guard let url = URL(string: sseURL) else {
            throw MCPError.invalidURL
        }
        
        print("🔧 Calling MCP tool: \(toolName)")
        
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
        
        print("📤 Sending tool call request")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        print("📡 Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 405 {
            print("⚠️ SSE endpoint requires streaming connection")
            throw MCPError.httpError(405)
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

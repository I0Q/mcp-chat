//
//  MCPClient.swift
//  HelloWorld
//
//  Generic MCP client that works with any MCP server using Server-Sent Events (SSE)
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
        
        print("🔗 Fetching tools from MCP server at: \(sseURL)")
        
        // MCP tools/list request using JSON-RPC 2.0
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
        
        print("📤 Sending tools/list request with ID: \(requestId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        print("📡 Response Status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ MCP Error: \(errorBody)")
            throw MCPError.httpError(httpResponse.statusCode)
        }
        
        // Parse JSON-RPC response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MCPError.invalidResponse
        }
        
        print("📦 Response: \(json)")
        
        // Parse MCP tools/list response
        guard let result = json["result"] as? [String: Any],
              let tools = result["tools"] as? [[String: Any]] else {
            print("⚠️ No tools in response")
            throw MCPError.invalidResponse
        }
        
        let parsedTools = tools.compactMap { toolDict -> MCPTool? in
            guard let name = toolDict["name"] as? String else { return nil }
            let description = toolDict["description"] as? String
            let inputSchema = toolDict["inputSchema"] as? [String: Any]
            
            return MCPTool(name: name, description: description)
        }
        
        print("✅ Fetched \(parsedTools.count) tools from MCP server")
        return parsedTools
    }
    
    // Call a tool on MCP server using SSE
    func callTool(toolName: String, arguments: [String: Any], sseURL: String, accessToken: String) async throws -> String {
        guard let url = URL(string: sseURL) else {
            throw MCPError.invalidURL
        }
        
        print("🔧 Calling MCP tool: \(toolName) with args: \(arguments)")
        
        // MCP tools/call request using JSON-RPC 2.0
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
        
        print("📤 Sending tools/call request with ID: \(requestId)")
        
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
        
        // Parse JSON-RPC response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MCPError.invalidResponse
        }
        
        print("📦 Response: \(json)")
        
        // Parse MCP tools/call response
        guard let result = json["result"] as? [String: Any] else {
            throw MCPError.invalidResponse
        }
        
        // Extract content from result
        if let content = result["content"] as? [[String: Any]] {
            // Content is an array of content items
            let textItems = content.compactMap { item -> String? in
                if let type = item["type"] as? String, type == "text",
                   let text = item["text"] as? String {
                    return text
                }
                return nil
            }
            return textItems.joined(separator: "\n")
        }
        
        if let text = result["text"] as? String {
            return text
        }
        
        // If we can't parse, return success
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

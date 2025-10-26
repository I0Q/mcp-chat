//
//  MCPClient.swift
//  HelloWorld
//
//  Generic MCP client using Server-Sent Events (SSE) transport
//

import Foundation

class MCPClient {
    static let shared = MCPClient()
    
    private init() {}
    
    // Fetch tools from MCP server using JSON-RPC
    func fetchTools(sseURL: String, accessToken: String) async throws -> [MCPTool] {
        // Remove /sse suffix if present to get the base URL
        var endpointURL = sseURL
        if endpointURL.hasSuffix("/mcp_server/sse") {
            endpointURL = String(endpointURL.dropLast(4)) // Remove "/sse"
        }
        
        guard let url = URL(string: endpointURL) else {
            throw MCPError.invalidURL
        }
        
        // Send JSON-RPC request in body
        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": UUID().uuidString,
            "params": [:]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add auth header if token provided
        if !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🔗 Fetching tools from MCP server")
        print("📍 Original URL: \(sseURL)")
        print("📍 Endpoint URL: \(endpointURL)")
        print("📤 Request: \(requestBody)")
        
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
        
        // Parse tools from JSON-RPC result
        var tools: [MCPTool] = []
        
        if let result = json["result"] as? [String: Any],
           let toolsArray = result["tools"] as? [[String: Any]] {
            tools = parseTools(toolsArray)
        } else if let toolsArray = json["tools"] as? [[String: Any]] {
            tools = parseTools(toolsArray)
        }
        
        print("✅ Fetched \(tools.count) tools")
        return tools
    }
    
    private func parseTools(_ toolsArray: [[String: Any]]) -> [MCPTool] {
        return toolsArray.compactMap { toolDict -> MCPTool? in
            guard let name = toolDict["name"] as? String else { return nil }
            
            var description: String? = nil
            if let desc = toolDict["description"] as? String {
                description = desc
            } else if let inputSchema = toolDict["inputSchema"] as? [String: Any],
                      let desc = inputSchema["description"] as? String {
                description = desc
            }
            
            return MCPTool(name: name, description: description)
        }
    }
    
    // Call a tool using JSON-RPC
    func callTool(toolName: String, arguments: [String: Any], sseURL: String, accessToken: String) async throws -> String {
        // Remove /sse suffix if present to get the base URL
        var endpointURL = sseURL
        if endpointURL.hasSuffix("/mcp_server/sse") {
            endpointURL = String(endpointURL.dropLast(4)) // Remove "/sse"
        }
        
        guard let url = URL(string: endpointURL) else {
            throw MCPError.invalidURL
        }
        
        // Send JSON-RPC request
        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "tools/call",
            "id": UUID().uuidString,
            "params": [
                "name": toolName,
                "arguments": arguments
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add auth header if token provided
        if !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🔧 Calling tool: \(toolName) with args: \(arguments)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
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
        
        // Extract content from result
        if let result = json["result"] as? [String: Any] {
            if let content = result["content"] as? [[String: Any]] {
                // Extract text items from content array
                let textItems = content.compactMap { item -> String? in
                    if let type = item["type"] as? String, type == "text",
                       let text = item["text"] as? String {
                        return text
                    }
                    return nil
                }
                return textItems.joined(separator: "\n")
            } else if let message = result["message"] as? String {
                return message
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
                return "Invalid response from server"
            case .httpError(let code):
                return "HTTP Error: \(code)"
            }
        }
    }
}

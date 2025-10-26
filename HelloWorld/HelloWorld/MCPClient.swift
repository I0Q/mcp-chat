//
//  MCPClient.swift
//  HelloWorld
//
//  MCP client supporting mcp-proxy integration
//

import Foundation

class MCPClient {
    static let shared = MCPClient()
    
    private init() {}
    
    // Fetch tools from MCP server via mcp-proxy
    func fetchTools(sseURL: String, accessToken: String) async throws -> [MCPTool] {
        let settings = SettingsManager.shared
        
        // Use proxy URL from settings, or default to localhost
        let proxyURLString = settings.mcpProxyURL.isEmpty ? "http://localhost:8000" : settings.mcpProxyURL
        let proxyURLStringWithPath = "\(proxyURLString)/tools/list"
        
        print("🔗 Connecting via mcp-proxy at: \(proxyURLString)")
        
        guard let proxyURL = URL(string: proxyURLStringWithPath) else {
            throw MCPError.invalidURL
        }
        
        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": UUID().uuidString,
            "params": [:]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw MCPError.invalidURL
        }
        
        print("📤 Sending request to mcp-proxy")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        print("📡 Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 404 || httpResponse.statusCode == 502 {
            print("⚠️ mcp-proxy not running")
            print("💡 To use mcp-proxy:")
            print("   1. Install: uv tool install git+https://github.com/sparfenyuk/mcp-proxy")
            print("   2. Run: mcp-proxy --sse-url \(sseURL) --access-token \(accessToken)")
            print("   3. The proxy will be available at http://localhost:8000")
            return []
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            print("❌ Error: \(errorBody)")
            throw MCPError.httpError(httpResponse.statusCode)
        }
        
        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MCPError.invalidResponse
        }
        
        print("📦 Response: \(json)")
        
        // Parse tools from various possible formats
        var tools: [MCPTool] = []
        
        if let result = json["result"] as? String, result == "tools",
           let toolsArray = json["tools"] as? [[String: Any]] {
            tools = parseTools(toolsArray)
        } else if let result = json["result"] as? [String: Any],
                  let toolsArray = result["tools"] as? [[String: Any]] {
            tools = parseTools(toolsArray)
        }
        
        print("✅ Fetched \(tools.count) tools via mcp-proxy")
        return tools
    }
    
    private func parseTools(_ toolsArray: [[String: Any]]) -> [MCPTool] {
        return toolsArray.compactMap { toolDict -> MCPTool? in
            guard let name = toolDict["name"] as? String else { return nil }
            let description = toolDict["description"] as? String
            return MCPTool(name: name, description: description)
        }
    }
    
    // Call a tool via mcp-proxy
    func callTool(toolName: String, arguments: [String: Any], sseURL: String, accessToken: String) async throws -> String {
        let settings = SettingsManager.shared
        
        let proxyURLString = settings.mcpProxyURL.isEmpty ? "http://localhost:8000" : settings.mcpProxyURL
        let proxyURLStringWithPath = "\(proxyURLString)/tools/call"
        
        print("🔧 Calling tool via mcp-proxy: \(toolName)")
        
        guard let proxyURL = URL(string: proxyURLStringWithPath) else {
            throw MCPError.invalidURL
        }
        
        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "tools/call",
            "id": UUID().uuidString,
            "params": [
                "name": toolName,
                "arguments": arguments
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw MCPError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        if httpResponse.statusCode == 404 || httpResponse.statusCode == 502 {
            print("⚠️ mcp-proxy not running")
            throw MCPError.notConnected
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
        case notConnected
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response from server"
            case .httpError(let code):
                return "HTTP Error: \(code)"
            case .notConnected:
                return "mcp-proxy not running"
            }
        }
    }
}

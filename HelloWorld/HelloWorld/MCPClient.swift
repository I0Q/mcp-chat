//
//  MCPClient.swift
//  HelloWorld
//
//  MCP client connecting to mcp-proxy on LLM server
//

import Foundation

class MCPClient {
    static let shared = MCPClient()
    
    private init() {}
    
    // Fetch tools from MCP server via mcp-proxy
    func fetchTools(sseURL: String, accessToken: String) async throws -> [MCPTool] {
        let settings = SettingsManager.shared
        
        // Connect to mcp-proxy at the configured URL
        // If no proxy URL is set, return empty tools (user needs to configure)
        let proxyURL = settings.mcpProxyURL.isEmpty ? "" : settings.mcpProxyURL
        
        guard !proxyURL.isEmpty else {
            print("⚠️ No mcp-proxy URL configured")
            print("💡 Set mcp-proxy URL in settings to use MCP tools")
            return []
        }
        let proxyURLStringWithPath = "\(proxyURL)/tools/list"
        
        print("🔗 Fetching tools from mcp-proxy at: \(proxyURL)")
        
        guard let url = URL(string: proxyURLStringWithPath) else {
            throw MCPError.invalidURL
        }
        
        var request = URLRequest(url: url)
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
        
        print("📤 Sending tools/list to mcp-proxy")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        print("📡 Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 404 || httpResponse.statusCode == 502 {
            print("⚠️ mcp-proxy not available")
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
        var tools: [MCPTool] = []
        
        if let result = json["result"] as? [String: Any],
           let toolsArray = result["tools"] as? [[String: Any]] {
            tools = parseTools(toolsArray)
        }
        
        print("✅ Fetched \(tools.count) tools from MCP server")
        return tools
    }
    
    private func parseTools(_ toolsArray: [[String: Any]]) -> [MCPTool] {
        return toolsArray.compactMap { toolDict -> MCPTool? in
            guard let name = toolDict["name"] as? String else { return nil }
            let description = toolDict["description"] as? String
            let inputSchema = toolDict["inputSchema"] as? [String: Any]
            
            return MCPTool(name: name, description: description)
        }
    }
    
    // Call a tool via mcp-proxy
    func callTool(toolName: String, arguments: [String: Any], sseURL: String, accessToken: String) async throws -> String {
        let settings = SettingsManager.shared
        
        let proxyURL = settings.mcpProxyURL.isEmpty ? "" : settings.mcpProxyURL
        
        guard !proxyURL.isEmpty else {
            print("⚠️ No mcp-proxy URL configured")
            throw MCPError.notConfigured
        }
        
        let proxyURLStringWithPath = "\(proxyURL)/tools/call"
        
        print("🔧 Calling tool via mcp-proxy: \(toolName) with args: \(arguments)")
        
        guard let url = URL(string: proxyURLStringWithPath) else {
            throw MCPError.invalidURL
        }
        
        var request = URLRequest(url: url)
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
            print("⚠️ mcp-proxy not available")
            throw MCPError.notConnected
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            print("❌ Error: \(errorBody)")
            throw MCPError.httpError(httpResponse.statusCode)
        }
        
        // Parse JSON-RPC 2.0 response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any] else {
            throw MCPError.invalidResponse
        }
        
        print("📦 Tool result: \(result)")
        
        // Extract content from result
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
        
        // Try alternative format
        if let text = result["text"] as? String {
            return text
        }
        
        return "Success"
    }
    
    enum MCPError: LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(Int)
        case notConnected
        case notConfigured
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response from server"
            case .httpError(let code):
                return "HTTP Error: \(code)"
            case .notConnected:
                return "Not connected to mcp-proxy"
            case .notConfigured:
                return "mcp-proxy URL not configured"
            }
        }
    }
}

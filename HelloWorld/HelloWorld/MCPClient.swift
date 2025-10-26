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
    
    // Fetch tools from MCP server using SSE
    func fetchTools(sseURL: String, accessToken: String) async throws -> [MCPTool] {
        guard let baseURL = URL(string: sseURL) else {
            throw MCPError.invalidURL
        }
        
        // For SSE, we need to send the request as part of the connection
        // Append the request as query parameter for the initial connection
        let requestId = UUID().uuidString
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "method", value: "tools/list"),
            URLQueryItem(name: "id", value: requestId)
        ]
        
        guard let url = components?.url else {
            throw MCPError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        // Add auth header if token provided
        if !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        print("🔗 Fetching tools from MCP server at: \(sseURL)")
        
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
        
        // Parse SSE response
        let responseString = String(data: data, encoding: .utf8) ?? ""
        print("📦 Response: \(responseString)")
        
        // Parse JSON-RPC response from SSE
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MCPError.invalidResponse
        }
        
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
    
    // Call a tool using SSE
    func callTool(toolName: String, arguments: [String: Any], sseURL: String, accessToken: String) async throws -> String {
        guard let baseURL = URL(string: sseURL) else {
            throw MCPError.invalidURL
        }
        
        // Build query parameters for SSE request
        let requestId = UUID().uuidString
        
        // Serialize arguments to JSON
        let argumentsJSON = try JSONSerialization.data(withJSONObject: arguments)
        let argumentsString = String(data: argumentsJSON, encoding: .utf8) ?? "{}"
        
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "method", value: "tools/call"),
            URLQueryItem(name: "id", value: requestId),
            URLQueryItem(name: "name", value: toolName),
            URLQueryItem(name: "arguments", value: argumentsString)
        ]
        
        guard let url = components?.url else {
            throw MCPError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        // Add auth header if token provided
        if !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        print("🔧 Calling tool via SSE: \(toolName) with args: \(arguments)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Error: \(errorBody)")
            throw MCPError.httpError(httpResponse.statusCode)
        }
        
        // Parse SSE response
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

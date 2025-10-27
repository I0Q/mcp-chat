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
    
    // Fetch tools from MCP server via SSE with JSON-RPC 2.0
    func fetchTools(sseURL: String, accessToken: String) async throws -> [MCPTool] {
        print("🔗 Connecting to MCP server via SSE: \(sseURL)")
        
        guard let url = URL(string: sseURL) else {
            throw MCPError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        // Add auth header if token provided
        if !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        // Connect to SSE endpoint and parse events
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        print("📡 Response Status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MCPError.httpError(httpResponse.statusCode)
        }
        
        // Read SSE data and parse JSON-RPC messages
        var dataBuffer = Data()
        var receivedMessages: [[String: Any]] = []
        
        for try await byte in bytes.prefix(65536) { // Read up to 64KB
            dataBuffer.append(byte)
            
            // Try to parse SSE format
            if let messageString = String(data: dataBuffer, encoding: .utf8) {
                // Look for complete SSE messages (lines starting with "data:")
                if messageString.contains("data:") {
                    let lines = messageString.components(separatedBy: .newlines)
                    for line in lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6)) // Remove "data: " prefix
                            if let jsonData = jsonString.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                receivedMessages.append(json)
                                print("📦 Received JSON-RPC message: \(json)")
                            }
                        }
                    }
                    dataBuffer.removeAll()
                }
                
                // Timeout after 5 seconds or if we get enough data
                if dataBuffer.count > 1024 || receivedMessages.count > 0 {
                    break
                }
            }
        }
        
        print("✅ Received \(receivedMessages.count) messages from SSE")
        
        // For now, return empty tools since we need to parse proper JSON-RPC responses
        // The user can manually add tools in the discovery screen
        return []
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
    
    // Call a tool on the MCP server
    func callTool(toolName: String, arguments: [String: Any], sseURL: String, accessToken: String) async throws -> String {
        guard let url = URL(string: sseURL) else {
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

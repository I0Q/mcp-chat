//
//  MCPService.swift
//  HelloWorld
//
//  Created by Acacio Santana on 10/26/25.
//

import Foundation

class MCPService {
    static let shared = MCPService()
    
    private init() {}
    
    func listTools() async throws -> [MCPTool] {
        let settings = SettingsManager.shared
        
        guard settings.mcpEnabled,
              let sseURL = URL(string: settings.mcpSSEURL),
              !settings.mcpAccessToken.isEmpty else {
            throw MCPError.notConfigured
        }
        
        var request = URLRequest(url: sseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(settings.mcpAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": UUID().uuidString
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MCPError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let mcpResponse = try decoder.decode(MCPListToolsResponse.self, from: data)
        
        return mcpResponse.result?.tools ?? []
    }
    
    func callTool(name: String, arguments: [String: Any]) async throws -> String {
        let settings = SettingsManager.shared
        
        guard settings.mcpEnabled,
              let sseURL = URL(string: settings.mcpSSEURL),
              !settings.mcpAccessToken.isEmpty else {
            throw MCPError.notConfigured
        }
        
        var request = URLRequest(url: sseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(settings.mcpAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": [
                "name": name,
                "arguments": arguments
            ],
            "id": UUID().uuidString
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MCPError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let mcpResponse = try decoder.decode(MCPCallToolResponse.self, from: data)
        
        return mcpResponse.result?.content?.first?.text ?? ""
    }
    
    enum MCPError: LocalizedError {
        case notConfigured
        case invalidResponse
        case httpError(Int)
        
        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "MCP not configured"
            case .invalidResponse:
                return "Invalid response from MCP server"
            case .httpError(let code):
                return "HTTP Error: \(code)"
            }
        }
    }
}

struct MCPTool: Codable {
    let name: String
    let description: String?
}

struct MCPListToolsResponse: Codable {
    let result: ToolsResult?
    
    struct ToolsResult: Codable {
        let tools: [MCPTool]
    }
}

struct MCPCallToolResponse: Codable {
    let result: CallResult?
    
    struct CallResult: Codable {
        let content: [ContentItem]?
        
        struct ContentItem: Codable {
            let type: String
            let text: String
        }
    }
}


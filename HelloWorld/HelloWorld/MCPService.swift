//
//  MCPService.swift
//  HelloWorld
//
//  Simplified MCP service wrapper - delegates to MCPClient
//

import Foundation

class MCPService {
    static let shared = MCPService()
    
    private var cachedTools: [MCPTool] = []
    
    private init() {}
    
    // Fetch tools from MCP server
    func fetchTools() async throws -> [MCPTool] {
        if !cachedTools.isEmpty {
            return cachedTools
        }
        
        let settings = SettingsManager.shared
        
        guard settings.mcpEnabled,
              !settings.mcpSSEURL.isEmpty,
              !settings.mcpAccessToken.isEmpty else {
            return []
        }
        
        do {
            let tools = try await MCPClient.shared.fetchTools(
                sseURL: settings.mcpSSEURL,
                accessToken: settings.mcpAccessToken
            )
            
            cachedTools = tools
            return tools
        } catch {
            print("⚠️ Could not fetch tools from MCP server: \(error)")
            return []
        }
    }
    
    // Get available tools
    func getAvailableTools() -> [MCPTool] {
        return cachedTools
    }
    
    // Call a tool on the MCP server
    func callTool(name: String, arguments: [String: Any]) async throws -> String {
        let settings = SettingsManager.shared
        
        guard settings.mcpEnabled,
              !settings.mcpSSEURL.isEmpty,
              !settings.mcpAccessToken.isEmpty else {
            throw MCPError.notConfigured
        }
        
        return try await MCPClient.shared.callTool(
            toolName: name,
            arguments: arguments,
            sseURL: settings.mcpSSEURL,
            accessToken: settings.mcpAccessToken
        )
    }
    
    enum MCPError: LocalizedError {
        case notConfigured
        
        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "MCP not configured"
            }
        }
    }
}

struct MCPTool: Codable {
    let name: String
    let description: String?
}

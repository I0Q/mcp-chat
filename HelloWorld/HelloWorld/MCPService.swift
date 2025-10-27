//
//  MCPService.swift
//  HelloWorld
//
//  Simplified MCP Service - direct API
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
        guard settings.mcpEnabled, !settings.mcpSSEURL.isEmpty else {
            return []
        }
        
        let tools = try await MCPClient.shared.fetchTools(
            sseURL: settings.mcpSSEURL,
            accessToken: settings.mcpAccessToken
        )
        
        cachedTools = tools
        return tools
    }
    
    // Call a tool on the MCP server
    func callTool(name: String, arguments: [String: Any]) async throws -> String {
        let settings = SettingsManager.shared
        guard settings.mcpEnabled, !settings.mcpSSEURL.isEmpty else {
            throw MCPError.invalidURL
        }
        
        return try await MCPClient.shared.callTool(
            toolName: name,
            arguments: arguments,
            sseURL: settings.mcpSSEURL,
            accessToken: settings.mcpAccessToken
        )
    }
}


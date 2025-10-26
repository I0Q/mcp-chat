//
//  MCPService.swift
//  HelloWorld
//
//  Generic MCP Service - thin wrapper around MCPClient
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
              !settings.mcpSSEURL.isEmpty else {
            print("⚠️ MCP not configured, returning empty tools")
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
            print("⚠️ Could not fetch tools from MCP server: \(error), returning empty tools")
            return []
        }
    }
    
    // Call a tool on the MCP server
    func callTool(name: String, arguments: [String: Any]) async throws -> String {
        let settings = SettingsManager.shared
        
        guard settings.mcpEnabled,
              !settings.mcpSSEURL.isEmpty else {
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


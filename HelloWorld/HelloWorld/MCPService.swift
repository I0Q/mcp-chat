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
    let title: String?
    let description: String?
    let inputSchema: [String: Any]?
    
    // Custom encoding/decoding for inputSchema as Any
    enum CodingKeys: String, CodingKey {
        case name, title, description, inputSchema
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        
        // inputSchema can be Any type, decode as JSON
        if let schemaData = try? container.decode(Data.self, forKey: .inputSchema) {
            inputSchema = try? JSONSerialization.jsonObject(with: schemaData) as? [String: Any]
        } else {
            inputSchema = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        if let schema = inputSchema {
            try container.encode(JSONSerialization.data(withJSONObject: schema), forKey: .inputSchema)
        }
    }
    
    init(name: String, title: String? = nil, description: String?, inputSchema: [String: Any]? = nil) {
        self.name = name
        self.title = title
        self.description = description
        self.inputSchema = inputSchema
    }
}


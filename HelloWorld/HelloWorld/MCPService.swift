//
//  MCPService.swift
//  HelloWorld
//
//  Created by Acacio Santana on 10/26/25.
//

import Foundation

class MCPService {
    static let shared = MCPService()
    private var eventSource: URLSessionDataTask?
    private var connected = false
    private var pendingRequests: [String: CheckedContinuation<[MCPTool], Error>] = [:]
    private var cachedTools: [MCPTool] = []
    private var requestId = 0
    
    private init() {}
    
    // Generate unique request ID
    private func nextRequestId() -> String {
        requestId += 1
        return "req-\(requestId)"
    }
    
    // Connect to MCP SSE endpoint and fetch tools using MCP protocol
    func connectAndFetchTools() async throws -> [MCPTool] {
        if !cachedTools.isEmpty {
            return cachedTools
        }
        
        let settings = SettingsManager.shared
        
        guard settings.mcpEnabled,
              !settings.mcpSSEURL.isEmpty,
              !settings.mcpAccessToken.isEmpty else {
            print("⚠️ MCP not configured, using default tools")
            return getDefaultTools()
        }
        
        do {
            // Use the new MCPClient to fetch tools
            let tools = try await MCPClient.shared.fetchTools(
                sseURL: settings.mcpSSEURL,
                accessToken: settings.mcpAccessToken
            )
            
            cachedTools = tools
            return tools
        } catch {
            print("⚠️ Could not fetch tools from MCP server: \(error), using defaults")
            return getDefaultTools()
        }
    }
    
    // Fetch tools - try MCP server first, fallback to defaults
    func fetchTools() async throws -> [MCPTool] {
        if !cachedTools.isEmpty {
            return cachedTools
        }
        
        do {
            let tools = try await connectAndFetchTools()
            cachedTools = tools
            return tools
        } catch {
            print("⚠️ Failed to fetch tools from MCP: \(error)")
            return getDefaultTools()
        }
    }
    
    // Get default tools as fallback
    func getDefaultTools() -> [MCPTool] {
        if !cachedTools.isEmpty {
            return cachedTools
        }
        
        return [
            MCPTool(name: "HassTurnOn", description: "Turn on an entity in Home Assistant. Arguments: name (entity name)"),
            MCPTool(name: "HassTurnOff", description: "Turn off an entity in Home Assistant. Arguments: name (entity name)"),
            MCPTool(name: "HassSetPosition", description: "Set the position of a cover. Arguments: name (entity name), position (0-100)"),
            MCPTool(name: "HassCancelAllTimers", description: "Cancel all timers. No arguments."),
            MCPTool(name: "HassLightSet", description: "Set light properties. Arguments: name (entity name), brightness (0-255), color_name (optional)"),
            MCPTool(name: "HassClimateSetTemperature", description: "Set climate temperature. Arguments: name (entity name), temperature"),
            MCPTool(name: "HassListAddItem", description: "Add item to list. Arguments: name (entity name), item"),
            MCPTool(name: "HassListCompleteItem", description: "Complete list item. Arguments: name (entity name), item"),
            MCPTool(name: "HassMediaUnpause", description: "Unpause media player. Arguments: name (entity name)"),
            MCPTool(name: "HassMediaPause", description: "Pause media player. Arguments: name (entity name)"),
            MCPTool(name: "HassMediaNext", description: "Next media item. Arguments: name (entity name)"),
            MCPTool(name: "HassMediaPrevious", description: "Previous media item. Arguments: name (entity name)"),
            MCPTool(name: "HassSetVolume", description: "Set volume. Arguments: name (entity name), volume (0-1)"),
            MCPTool(name: "HassSetVolumeRelative", description: "Change volume relatively. Arguments: name (entity name), change (positive or negative)"),
            MCPTool(name: "HassMediaSearchAndPlay", description: "Search and play media. Arguments: name (entity name), query"),
            MCPTool(name: "todo_get_items", description: "Get todo items. Arguments: name (entity name)"),
            MCPTool(name: "GetLiveContext", description: "Get live context from Home Assistant")
        ]
    }
    
    // Get available tools (try to fetch from server, fallback to defaults)
    func getAvailableTools() -> [MCPTool] {
        // Return default tools for now - will be fetched when MCP is enabled
        return getDefaultTools()
    }
    
    func callTool(name: String, arguments: [String: Any]) async throws -> String {
        let settings = SettingsManager.shared
        
        guard settings.mcpEnabled,
              let baseURL = URL(string: settings.mcpSSEURL.replacingOccurrences(of: "/mcp_server/sse", with: "")),
              !settings.mcpAccessToken.isEmpty else {
            throw MCPError.notConfigured
        }
        
        // Use MCP Client to call tools via conversation API
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
        case httpErrorWithDetails(Int, String)
        case invalidArguments
        
        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "MCP not configured"
            case .invalidResponse:
                return "Invalid response from MCP server"
            case .httpError(let code):
                return "HTTP Error: \(code)"
            case .httpErrorWithDetails(let code, let details):
                return "HTTP Error \(code): \(details)"
            case .invalidArguments:
                return "Invalid arguments for tool"
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

struct AssistIntentsResponse: Codable {
    let intents: [AssistIntent]?
    
    struct AssistIntent: Codable {
        let name: String
        let description: String?
    }
}


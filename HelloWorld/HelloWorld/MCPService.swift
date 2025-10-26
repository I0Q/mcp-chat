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
    
    // Map Home Assistant MCP tool names to actual services
    private func mapToolToService(_ toolName: String) -> (domain: String, service: String) {
        switch toolName {
        case "HassTurnOn":
            return ("homeassistant", "turn_on")
        case "HassTurnOff":
            return ("homeassistant", "turn_off")
        case "HassSetCoverPosition":
            return ("cover", "set_cover_position")
        case "HassSetClimateTemperature":
            return ("climate", "set_temperature")
        case "HassGetCameraSnapshot":
            return ("camera", "snapshot")
        case "HassPlayMedia":
            return ("media_player", "play_media")
        case "HassStartTimer":
            return ("timer", "start")
        case "HassPauseTimer":
            return ("timer", "pause")
        case "HassRestartTimer":
            return ("timer", "restart")
        case "HassCancelTimer":
            return ("timer", "cancel")
        default:
            return ("homeassistant", "turn_on")
        }
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
        
        // Try to use MCP protocol first via MCPClient
        // If that fails, fall back to direct Home Assistant API calls
        if let mcpResult = try? await MCPClient.shared.callTool(
            toolName: name,
            arguments: arguments,
            sseURL: settings.mcpSSEURL,
            accessToken: settings.mcpAccessToken
        ) {
            return mcpResult
        }
        
        // Fallback to direct Home Assistant API calls
        let apiURL: URL
        let method: String
        var requestBody: [String: Any] = [:]
        
        // Map tool names to Home Assistant services
        let (domain, service) = mapToolToService(name)
        apiURL = baseURL.appendingPathComponent("/api/services/\(domain)/\(service)")
        method = "POST"
        
        // Build service data from arguments
        var serviceData: [String: Any] = [:]
        
        // Add all arguments as service data
        for (key, value) in arguments {
            if let strValue = value as? String {
                serviceData[key] = strValue
            } else if let arrayValue = value as? [Any], let firstItem = arrayValue.first as? String {
                // Handle arrays - take first element
                serviceData[key] = firstItem
            } else {
                serviceData[key] = value
            }
        }
        
        requestBody = serviceData
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = method
        request.setValue("Bearer \(settings.mcpAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Debug logging
        print("🔧 MCP Tool Call:")
        print("  Name: \(name)")
        print("  URL: \(apiURL)")
        print("  Method: \(method)")
        print("  Arguments: \(arguments)")
        print("  Request Body: \(requestBody)")
        
        if !requestBody.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
                print("  Request Body (JSON): \(bodyString)")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        print("📡 Response Status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Include response body in error for debugging
            let errorBody = String(data: data, encoding: .utf8) ?? "No error message"
            print("❌ Error Response: \(errorBody)")
            let statusCode = httpResponse.statusCode
            throw MCPError.httpErrorWithDetails(statusCode, errorBody)
        }
        
        print("✅ Success!")
        
        // Return the response as a string
        if let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }
        return "Success"
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


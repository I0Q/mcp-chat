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
    private var pendingRequests: [String: CheckedContinuation<Data, Error>] = [:]
    
    private init() {}
    
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
    
    // Home Assistant MCP tools - these are the actual tools exposed by the MCP server
    // Based on Home Assistant's conversation/assist API
    func getAvailableTools() -> [MCPTool] {
        return [
            MCPTool(name: "HassTurnOn", description: "Turn on an entity in Home Assistant. Arguments: name (entity name), area (optional area name)"),
            MCPTool(name: "HassTurnOff", description: "Turn off an entity in Home Assistant. Arguments: name (entity name), area (optional area name)"),
            MCPTool(name: "HassSetCoverPosition", description: "Set the position of a cover. Arguments: name (entity name), area (optional), position (0-100)"),
            MCPTool(name: "HassSetClimateTemperature", description: "Set the temperature of a climate entity. Arguments: name (entity name), temperature"),
            MCPTool(name: "HassGetCameraSnapshot", description: "Get a snapshot from a camera. Arguments: name (entity name)"),
            MCPTool(name: "HassNavigate", description: "Navigate in the map. Arguments: name (entity name), gps (GPS coordinates)"),
            MCPTool(name: "HassPlayMedia", description: "Play media on a media player. Arguments: name (entity name), media_content_id, media_content_type"),
            MCPTool(name: "HassCancelTimer", description: "Cancel a timer. Arguments: name (entity name)"),
            MCPTool(name: "HassPauseTimer", description: "Pause a timer. Arguments: name (entity name)"),
            MCPTool(name: "HassStartTimer", description: "Start a timer. Arguments: name (entity name), duration"),
            MCPTool(name: "HassRestartTimer", description: "Restart a timer. Arguments: name (entity name)")
        ]
    }
    
    func callTool(name: String, arguments: [String: Any]) async throws -> String {
        let settings = SettingsManager.shared
        
        guard settings.mcpEnabled,
              let baseURL = URL(string: settings.mcpSSEURL.replacingOccurrences(of: "/mcp_server/sse", with: "")),
              !settings.mcpAccessToken.isEmpty else {
            throw MCPError.notConfigured
        }
        
        // Use Home Assistant's API directly instead of MCP SSE protocol
        // This is a simplified approach - in production you'd use proper SSE streaming
        let apiURL: URL
        let method: String
        var requestBody: [String: Any] = [:]
        
        // Home Assistant MCP tools - these are Assist API conversation intents
        // We need to map the tool to the appropriate Home Assistant service call
        method = "POST"
        
        // Map tool names to Home Assistant services
        let (domain, service) = mapToolToService(name)
        apiURL = baseURL.appendingPathComponent("/api/services/\(domain)/\(service)")
        
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


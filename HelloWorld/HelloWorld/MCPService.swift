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
    
    // Simplified MCP tools - hardcoded for Home Assistant based on documentation
    // The actual tools are exposed by the Assist API
    func getAvailableTools() -> [MCPTool] {
        return [
            MCPTool(name: "get_states", description: "Get the current states of entities in Home Assistant"),
            MCPTool(name: "set_state", description: "Set the state of an entity in Home Assistant"),
            MCPTool(name: "call_service", description: "Call a Home Assistant service"),
            MCPTool(name: "get_device_info", description: "Get information about a device"),
            MCPTool(name: "get_config", description: "Get the Home Assistant configuration")
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
        
        switch name {
        case "call_service":
            method = "POST"
            guard let domain = arguments["domain"] as? String,
                  let service = arguments["service"] as? String else {
                throw MCPError.invalidArguments
            }
            apiURL = baseURL.appendingPathComponent("/api/services/\(domain)/\(service)")
            // Home Assistant expects service data directly as request body
            // Extract service_data from arguments or use arguments directly
            requestBody = arguments["service_data"] as? [String: Any] ?? arguments
            
        case "get_states":
            method = "GET"
            apiURL = baseURL.appendingPathComponent("/api/states")
            
        case "set_state":
            method = "POST"
            guard let entityId = arguments["entity_id"] as? String else {
                throw MCPError.invalidArguments
            }
            let state = arguments["state"] as? String ?? ""
            let attributes = arguments["attributes"] as? [String: Any] ?? [:]
            apiURL = baseURL.appendingPathComponent("/api/states/\(entityId)")
            requestBody = [
                "state": state,
                "attributes": attributes
            ]
            
        default:
            return "Tool \(name) not yet implemented in simplified client"
        }
        
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


//
//  MCPClient.swift
//  HelloWorld
//
//  MCP client with SSE (Server-Sent Events) support
//

import Foundation

class MCPClient {
    static let shared = MCPClient()
    
    private init() {}
    
    // Fetch tools from MCP server via SSE
    func fetchTools(sseURL: String, accessToken: String) async throws -> [MCPTool] {
        // For iOS, implementing full SSE protocol is complex
        // The SSE endpoint expects a persistent GET connection
        // We'll use Home Assistant's REST API for now as a practical workaround
        
        guard let baseURL = URL(string: sseURL.replacingOccurrences(of: "/mcp_server/sse", with: "")) else {
            throw MCPError.invalidURL
        }
        
        // Use Home Assistant's Assist API to discover intents/tools
        let intentsURL = baseURL.appendingPathComponent("/api/assist_pipeline/conversation/intents")
        
        var request = URLRequest(url: intentsURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🔗 Fetching tools from Home Assistant")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MCPError.httpError(httpResponse.statusCode)
        }
        
        // Parse intents as MCP tools
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let intents = json["intents"] as? [[String: Any]] {
            
            let tools = intents.compactMap { intent -> MCPTool? in
                guard let name = intent["name"] as? String else { return nil }
                let description = intent["description"] as? String
                return MCPTool(name: name, description: description)
            }
            
            print("✅ Fetched \(tools.count) tools")
            return tools
        }
        
        return []
    }
    
    // Call a tool via Home Assistant's conversation API
    func callTool(toolName: String, arguments: [String: Any], sseURL: String, accessToken: String) async throws -> String {
        guard let baseURL = URL(string: sseURL.replacingOccurrences(of: "/mcp_server/sse", with: "")) else {
            throw MCPError.invalidURL
        }
        
        let conversationURL = baseURL.appendingPathComponent("/api/conversation/process")
        
        // Build natural language command
        var command = ""
        if let name = arguments["name"] as? String {
            if toolName == "HassTurnOn" {
                command = "turn on \(name)"
            } else if toolName == "HassTurnOff" {
                command = "turn off \(name)"
            } else if toolName == "HassSetPosition" {
                if let position = arguments["position"] {
                    command = "set \(name) to position \(position)"
                } else {
                    command = "set \(name)"
                }
            } else {
                command = name
            }
            command = command.replacingOccurrences(of: "_", with: " ")
        } else {
            command = toolName.replacingOccurrences(of: "Hass", with: "").replacingOccurrences(of: "_", with: " ")
        }
        
        let requestBody: [String: Any] = [
            "text": command
        ]
        
        var request = URLRequest(url: conversationURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🔧 Calling tool: \(command)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            print("❌ Error: \(errorBody)")
            throw MCPError.httpError(httpResponse.statusCode)
        }
        
        // Parse response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let speech = json["speech"] as? [String: Any],
               let plain = speech["plain"] as? [String: Any],
               let speechText = plain["speech"] as? String {
                return speechText
            }
            
            if let message = json["message"] as? String {
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

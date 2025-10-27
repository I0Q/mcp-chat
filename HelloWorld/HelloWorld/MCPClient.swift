//
//  MCPClient.swift
//  HelloWorld
//
//  Generic MCP client - Direct SSE implementation following MCP spec
//  Communicates with MCP servers via HTTP+SSE transport
//

import Foundation

class MCPClient {
    static let shared = MCPClient()
    
    private var cachedTools: [MCPTool] = []
    
    private init() {}
    
    // Helper to get session endpoint from SSE
    private func getSessionEndpoint(sseURL: String, accessToken: String) async throws -> String? {
        guard let baseURL = URL(string: sseURL) else { return nil }
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "GET"
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        if !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { return nil }
        
        // Parse SSE for "event: endpoint" and "data: /messages/..."
        var dataBuffer = Data()
        for try await byte in bytes.prefix(8192) {
            dataBuffer.append(byte)
            if let messageString = String(data: dataBuffer, encoding: .utf8) {
                let lines = messageString.components(separatedBy: .newlines)
                for (index, line) in lines.enumerated() {
                    if line == "event: endpoint" && index + 1 < lines.count {
                        let dataLine = lines[index + 1]
                        if dataLine.hasPrefix("data: ") {
                            return String(dataLine.dropFirst(6))
                        }
                    }
                }
            }
            if dataBuffer.count > 4096 { break }
        }
        return nil
    }
    
    // Fetch tools from MCP server (with caching, pulls from settings)
    func fetchTools() async throws -> [MCPTool] {
        if !cachedTools.isEmpty { return cachedTools }
        
        let settings = SettingsManager.shared
        guard settings.mcpEnabled, !settings.mcpSSEURL.isEmpty else { return [] }
        
        cachedTools = try await fetchToolsFromServer(sseURL: settings.mcpSSEURL, accessToken: settings.mcpAccessToken)
        return cachedTools
    }
    
    // Fetch tools from MCP server via SSE transport
    private func fetchToolsFromServer(sseURL: String, accessToken: String) async throws -> [MCPTool] {
        guard let endpoint = try await getSessionEndpoint(sseURL: sseURL, accessToken: accessToken) else {
            print("❌ Could not get session endpoint from SSE")
            return []
        }
        
        // Step 3: Build full messages URL
        var messagesURLString = sseURL
        if messagesURLString.hasSuffix("/sse") {
            messagesURLString = String(messagesURLString.dropLast(4))
        }
        
        // Remove any leading slash from endpoint
        let cleanEndpoint = endpoint.hasPrefix("/") ? String(endpoint.dropFirst()) : endpoint
        let fullURL = "\(messagesURLString)\(cleanEndpoint.hasPrefix("/") ? "" : "/")\(cleanEndpoint)"
        
        guard let messagesURL = URL(string: fullURL) else {
            print("❌ Invalid messages URL: \(fullURL)")
            return []
        }
        
        print("🔗 Sending tools/list to: \(fullURL)")
        
        // Step 4: Send JSON-RPC request to messages endpoint
        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": UUID().uuidString,
            "params": [:]
        ]
        
        var messagesRequest = URLRequest(url: messagesURL)
        messagesRequest.httpMethod = "POST"
        messagesRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Per MCP spec, include both content types in Accept header
        messagesRequest.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        messagesRequest.timeoutInterval = 10
        
        let settings = SettingsManager.shared
        if settings.mcpUseAuth && !accessToken.isEmpty {
            messagesRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        messagesRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, messagesResponse) = try await URLSession.shared.data(for: messagesRequest)
        
        guard let httpMessagesResponse = messagesResponse as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        print("📡 Messages Response Status: \(httpMessagesResponse.statusCode)")
        
        guard (200...299).contains(httpMessagesResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            print("❌ Error: \(errorBody)")
            throw MCPError.httpError(httpMessagesResponse.statusCode)
        }
        
        // Parse tools from response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ Could not parse JSON response")
            return []
        }
        
        print("📦 Response: \(json)")
        
        var tools: [MCPTool] = []
        if let result = json["result"] as? [String: Any],
           let toolsArray = result["tools"] as? [[String: Any]] {
            tools = parseTools(toolsArray)
        }
        
        print("✅ Fetched \(tools.count) tools")
        return tools
    }
    
    private func parseTools(_ toolsArray: [[String: Any]]) -> [MCPTool] {
        return toolsArray.compactMap { toolDict -> MCPTool? in
            guard let name = toolDict["name"] as? String else { return nil }
            
            // Per MCP spec: name (required), title (optional), description (required)
            let title = toolDict["title"] as? String
            let description = toolDict["description"] as? String
            let inputSchema = toolDict["inputSchema"] as? [String: Any]
            
            return MCPTool(
                name: name,
                title: title,
                description: description,
                inputSchema: inputSchema
            )
        }
    }
    
    // Call a tool on the MCP server (pulls from settings)
    func callTool(name: String, arguments: [String: Any]) async throws -> String {
        let settings = SettingsManager.shared
        guard settings.mcpEnabled, !settings.mcpSSEURL.isEmpty else {
            throw MCPError.invalidURL
        }
        
        return try await callToolOnServer(name: name, arguments: arguments, sseURL: settings.mcpSSEURL, accessToken: settings.mcpAccessToken)
    }
    
    // Call a tool on the MCP server
    private func callToolOnServer(name: String, arguments: [String: Any], sseURL: String, accessToken: String) async throws -> String {
        guard let endpoint = try await getSessionEndpoint(sseURL: sseURL, accessToken: accessToken) else {
            throw MCPError.invalidResponse
        }
        
        // Step 2: Build full messages URL
        var messagesURLString = sseURL
        if messagesURLString.hasSuffix("/sse") {
            messagesURLString = String(messagesURLString.dropLast(4))
        }
        
        let cleanEndpoint = endpoint.hasPrefix("/") ? String(endpoint.dropFirst()) : endpoint
        let fullURL = "\(messagesURLString)\(cleanEndpoint.hasPrefix("/") ? "" : "/")\(cleanEndpoint)"
        
        guard let messagesURL = URL(string: fullURL) else {
            throw MCPError.invalidURL
        }
        
        // Step 3: Send JSON-RPC request to messages endpoint
        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "tools/call",
            "id": UUID().uuidString,
            "params": [
                "name": name,
                "arguments": arguments
            ]
        ]
        
        var messagesRequest = URLRequest(url: messagesURL)
        messagesRequest.httpMethod = "POST"
        messagesRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        messagesRequest.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        messagesRequest.timeoutInterval = 10
        
        let settings = SettingsManager.shared
        if settings.mcpUseAuth && !accessToken.isEmpty {
            messagesRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        messagesRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, messagesResponse) = try await URLSession.shared.data(for: messagesRequest)
        
        guard let httpMessagesResponse = messagesResponse as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        guard (200...299).contains(httpMessagesResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Error: \(errorBody)")
            throw MCPError.httpError(httpMessagesResponse.statusCode)
        }
        
        // Parse JSON-RPC response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MCPError.invalidResponse
        }
        
        print("📦 Response: \(json)")
        
        // Extract content from result
        if let result = json["result"] as? [String: Any] {
            if let content = result["content"] as? [[String: Any]] {
                // Extract text items from content array
                let textItems = content.compactMap { item -> String? in
                    if let type = item["type"] as? String, type == "text",
                       let text = item["text"] as? String {
                        return text
                    }
                    return nil
                }
                return textItems.joined(separator: "\n")
            } else if let message = result["message"] as? String {
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
            case .invalidURL: return "Invalid URL"
            case .invalidResponse: return "Invalid response from server"
            case .httpError(let code): return "HTTP Error: \(code)"
            }
        }
    }
}

// MCP Data Models
struct MCPTool: Codable {
    let name: String
    let title: String?
    let description: String?
    let inputSchema: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case name, title, description, inputSchema
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        
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

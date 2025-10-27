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
    
    // Helper to parse session endpoint from SSE bytes stream
    private func parseSessionEndpoint(from bytes: URLSession.AsyncBytes) async throws -> String? {
        var dataBuffer = Data()
        var lastLineIndex = 0
        var waitingForData = false
        
        for try await byte in bytes.prefix(8192) {
            dataBuffer.append(byte)
            
            if let partialString = String(data: dataBuffer, encoding: .utf8) {
                let lines = partialString.components(separatedBy: .newlines)
                
                if lines.count <= lastLineIndex {
                    continue
                }
                
                for index in lastLineIndex..<(lines.count - 1) {
                    let line = lines[index]
                    let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                    
                    if waitingForData {
                        if !trimmedLine.isEmpty && trimmedLine.hasPrefix("data: ") {
                            let endpoint = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                            print("✅ Session endpoint found: \(endpoint)")
                            return endpoint
                        }
                    } else if trimmedLine == "event: endpoint" {
                        waitingForData = true
                        print("📍 Found event: endpoint, waiting for data: line...")
                    }
                }
                lastLineIndex = lines.count - 1
            }
            
            if dataBuffer.count > 4096 { break }
        }
        return nil
    }
    
    // Helper to get session endpoint from SSE
    private func getSessionEndpoint(sseURL: String, accessToken: String) async throws -> String? {
        guard let baseURL = URL(string: sseURL) else { 
            print("❌ Invalid SSE URL: \(sseURL)")
            return nil 
        }
        
        print("🔗 Connecting to: \(sseURL)")
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "GET"
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("2025-06-18", forHTTPHeaderField: "MCP-Protocol-Version")
        request.timeoutInterval = 30
        
        let settings = SettingsManager.shared
        if settings.mcpUseAuth && !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response")
                return nil
            }
            
            print("📡 Response status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ Bad status code: \(httpResponse.statusCode)")
                return nil
            }
        
        // Parse SSE for "event: endpoint" and "data: /messages/..."
        var dataBuffer = Data()
        var lastLineIndex = 0
        var waitingForData = false
        
        for try await byte in bytes.prefix(8192) {
            dataBuffer.append(byte)
            
            // Only parse complete lines (wait for newline characters)
            if let partialString = String(data: dataBuffer, encoding: .utf8) {
                // Split by actual newline characters
                let lines = partialString.components(separatedBy: .newlines)
                
                // Only process if we have more complete lines than last time
                if lines.count <= lastLineIndex {
                    // No new complete lines yet, keep reading
                    continue
                }
                
                // Process new complete lines
                for index in lastLineIndex..<(lines.count - 1) { // -1 to skip partial last line
                    let line = lines[index]
                    let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                    
                    if waitingForData {
                        // We're looking for a data: line after finding event: endpoint
                        if !trimmedLine.isEmpty && trimmedLine.hasPrefix("data: ") {
                            let endpoint = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                            print("✅ Session endpoint: \(endpoint)")
                            return endpoint
                        }
                    } else if trimmedLine == "event: endpoint" {
                        // Look for "data: ..." in subsequent lines
                        waitingForData = true
                        print("📍 Found event: endpoint, waiting for data: line...")
                    }
                }
                lastLineIndex = lines.count - 1  // Update to skip partial line
            }
            
            if dataBuffer.count > 4096 { 
                print("⚠️ Buffer size exceeded 4KB, stopping")
                break 
            }
        }
        
        print("❌ Could not find session endpoint in SSE stream")
        if let lastString = String(data: dataBuffer, encoding: .utf8) {
            print("📄 Last received data: \(lastString.prefix(200))")
        }
        return nil
        } catch {
            print("❌ Connection error: \(error)")
            throw error
        }
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
        // Home Assistant MCP server: session only valid while SSE connection is open
        // Strategy: Open SSE connection, get endpoint, make POST while connection is open
        
        guard let baseURL = URL(string: sseURL) else {
            print("❌ Invalid SSE URL")
            return []
        }
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "GET"
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("2025-06-18", forHTTPHeaderField: "MCP-Protocol-Version")
        request.timeoutInterval = 30
        
        let settings = SettingsManager.shared
        if settings.mcpUseAuth && !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            print("❌ Bad SSE response")
            return []
        }
        
        // Parse SSE to get session endpoint
        guard let endpoint = try await parseSessionEndpoint(from: bytes) else {
            print("❌ Could not parse session endpoint")
            return []
        }
        
        print("✅ Got session endpoint: \(endpoint)")
        
        // Step 3: Build full messages URL from base SSE URL
        // Extract base URL (before /sse suffix)
        var baseURLString = sseURL
        if baseURLString.hasSuffix("/sse") {
            baseURLString = String(baseURLString.dropLast(4))
        }
        
        // Extract base URL host and port, then use the endpoint path directly
        guard let baseURL = URL(string: baseURLString) else {
            print("❌ Invalid base URL: \(baseURLString)")
            return []
        }
        
        // The endpoint is an absolute path like /mcp_server/messages/...
        // Construct full URL: scheme://host:port + endpoint
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespaces)
        let fullURL = "\(baseURL.scheme ?? "http")://\(baseURL.host ?? ""):\(baseURL.port ?? 8123)\(trimmedEndpoint)"
        
        guard let messagesURL = URL(string: fullURL) else {
            print("❌ Invalid messages URL: \(fullURL)")
            return []
        }
        
        print("🔗 Sending tools/list to: \(fullURL)")
        print("   Base URL: \(baseURLString)")
        print("   Endpoint: \(trimmedEndpoint)")
        
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
        messagesRequest.setValue("2025-06-18", forHTTPHeaderField: "MCP-Protocol-Version")
        messagesRequest.timeoutInterval = 10
        
        // Use settings from earlier in function
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
        
        // Step 2: Build full messages URL from base SSE URL
        var baseURLString = sseURL
        if baseURLString.hasSuffix("/sse") {
            baseURLString = String(baseURLString.dropLast(4))
        }
        
        guard let baseURL = URL(string: baseURLString) else {
            throw MCPError.invalidURL
        }
        
        // The endpoint is an absolute path like /mcp_server/messages/...
        // Construct full URL: scheme://host:port + endpoint
        let fullURL = "\(baseURL.scheme ?? "http")://\(baseURL.host ?? ""):\(baseURL.port ?? 8123)\(endpoint.trimmingCharacters(in: .whitespaces))"
        
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
        messagesRequest.setValue("2025-06-18", forHTTPHeaderField: "MCP-Protocol-Version")
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

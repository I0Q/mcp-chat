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
    private var lastMCPConfig: String = "" // Track when settings change
    
    private init() {}
    
    // Clear the tools cache (call when MCP settings change)
    func clearCache() {
        cachedTools.removeAll()
        lastMCPConfig = ""
        print("🗑️ MCP tools cache cleared")
    }
    
    // Force refresh tools from server
    func refreshTools() async throws -> [MCPTool] {
        cachedTools.removeAll()
        return try await fetchTools()
    }
    
    // Generate a cache key from current MCP settings
    private func getCurrentConfigKey() -> String {
        let settings = SettingsManager.shared
        return "\(settings.mcpSSEURL)|\(settings.mcpAccessToken)|\(settings.mcpEnabled)"
    }
    
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
    
    // Fetch tools from MCP server (with smart caching)
    func fetchTools() async throws -> [MCPTool] {
        let settings = SettingsManager.shared
        guard settings.mcpEnabled, !settings.mcpSSEURL.isEmpty else {
            cachedTools = []
            return []
        }
        
        // Check if config changed - clear cache if it did
        let currentConfig = getCurrentConfigKey()
        if currentConfig != lastMCPConfig {
            print("🔄 MCP configuration changed, clearing cache")
            cachedTools.removeAll()
        }
        
        // Return cached tools if available
        if !cachedTools.isEmpty {
            print("📦 Returning \(cachedTools.count) cached tools")
            return cachedTools
        }
        
        // Fetch fresh tools
        print("🔄 Fetching tools from MCP server...")
        cachedTools = try await fetchToolsFromServer(sseURL: settings.mcpSSEURL, accessToken: settings.mcpAccessToken)
        lastMCPConfig = currentConfig
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
        
        // Parse the endpoint from the SSE stream
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
        
        // Step 4: Initialize MCP session
        let initID = UUID().uuidString
        let initJSON = """
        {
            "jsonrpc": "2.0",
            "method": "initialize",
            "id": "\(initID)",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {
                    "name": "MCP iOS Client",
                    "version": "1.0"
                }
            }
        }
        """
        
        var initRequest = URLRequest(url: messagesURL)
        initRequest.httpMethod = "POST"
        initRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        initRequest.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        initRequest.setValue("2024-11-05", forHTTPHeaderField: "MCP-Protocol-Version")
        initRequest.timeoutInterval = 30
        
        if settings.mcpUseAuth && !accessToken.isEmpty {
            initRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        initRequest.httpBody = initJSON.data(using: .utf8)
        let (_, initResponse) = try await URLSession.shared.data(for: initRequest)
        guard let httpInitResponse = initResponse as? HTTPURLResponse,
              (200...299).contains(httpInitResponse.statusCode) else {
            throw MCPError.httpError((initResponse as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        // Read initialize response from SSE
        var dataBuffer = Data()
        var lastLineIndex = 0
        var waitingForMessage = false
        var initResponseData: String?
        
        for try await byte in bytes.prefix(16384) {
            dataBuffer.append(byte)
            if let partialString = String(data: dataBuffer, encoding: .utf8) {
                let lines = partialString.components(separatedBy: .newlines)
                if lines.count <= lastLineIndex { continue }
                for index in lastLineIndex..<(lines.count - 1) {
                    let line = lines[index].trimmingCharacters(in: .whitespaces)
                    if waitingForMessage && line.hasPrefix("data: ") {
                        let data = String(line.dropFirst(6))
                        if data.contains("\"id\":\"\(initID)\"") {
                            initResponseData = data
                            break
                        }
                    } else if line == "event: message" {
                        waitingForMessage = true
                    }
                }
                lastLineIndex = lines.count - 1
                if initResponseData != nil { break }
            }
            if dataBuffer.count > 8192 { break }
        }
        
        // Step 5: Send notifications/initialized
        let notifJSON = """
        {
            "jsonrpc": "2.0",
            "method": "notifications/initialized",
            "params": {}
        }
        """
        
        var notifRequest = URLRequest(url: messagesURL)
        notifRequest.httpMethod = "POST"
        notifRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        notifRequest.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        notifRequest.setValue("2024-11-05", forHTTPHeaderField: "MCP-Protocol-Version")
        notifRequest.timeoutInterval = 10
        
        if settings.mcpUseAuth && !accessToken.isEmpty {
            notifRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        notifRequest.httpBody = notifJSON.data(using: .utf8)
        let (_, notifResponse) = try await URLSession.shared.data(for: notifRequest)
        guard let httpNotifResponse = notifResponse as? HTTPURLResponse,
              (200...299).contains(httpNotifResponse.statusCode) else {
            throw MCPError.httpError((notifResponse as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        // Step 6: Send tools/list request
        let toolsID = UUID().uuidString
        let toolsJSON = """
        {
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": "\(toolsID)",
            "params": {}
        }
        """
        
        var toolsRequest = URLRequest(url: messagesURL)
        toolsRequest.httpMethod = "POST"
        toolsRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        toolsRequest.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        toolsRequest.setValue("2024-11-05", forHTTPHeaderField: "MCP-Protocol-Version")
        toolsRequest.timeoutInterval = 30
        
        if settings.mcpUseAuth && !accessToken.isEmpty {
            toolsRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        toolsRequest.httpBody = toolsJSON.data(using: .utf8)
        let (_, toolsResponse) = try await URLSession.shared.data(for: toolsRequest)
        guard let httpToolsResponse = toolsResponse as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        print("📡 Messages Response Status: \(httpToolsResponse.statusCode)")
        
        guard (200...299).contains(httpToolsResponse.statusCode) else {
            throw MCPError.httpError(httpToolsResponse.statusCode)
        }
        
        // Step 7: Read tools/list response from the SSE stream
        var toolsDataBuffer = Data()
        var toolsLastLineIndex = 0
        var toolsWaitingForMessage = false
        var responseData: String?
        
        for try await byte in bytes.prefix(32768) {
            toolsDataBuffer.append(byte)
            
            if let partialString = String(data: toolsDataBuffer, encoding: .utf8) {
                let lines = partialString.components(separatedBy: .newlines)
                
                if lines.count <= toolsLastLineIndex {
                    continue
                }
                
                for index in toolsLastLineIndex..<(lines.count - 1) {
                    let line = lines[index].trimmingCharacters(in: .whitespaces)
                    
                    if toolsWaitingForMessage {
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))
                            if data.contains("\"id\":\"\(toolsID)\"") {
                                responseData = data
                                break
                            }
                        }
                    } else if line == "event: message" {
                        toolsWaitingForMessage = true
                    }
                }
                
                toolsLastLineIndex = lines.count - 1
                
                if responseData != nil {
                    break
                }
            }
            
            if toolsDataBuffer.count > 16384 {
                print("⚠️ SSE buffer too large, stopping")
                break
            }
        }
        
        guard let responseData = responseData else {
            print("❌ Did not receive JSON-RPC response in SSE stream")
            return []
        }
        
        print("📄 SSE response data: \(responseData.prefix(200))...")
        
        guard let jsonData = responseData.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            print("❌ Could not parse JSON response")
            return []
        }
        
        print("📦 Response keys: \(json.keys.joined(separator: ", "))")
        
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
        // Open a new SSE session for this tool call
        guard let baseURL = URL(string: sseURL) else {
            throw MCPError.invalidURL
        }
        
        print("🔧 Calling tool: \(name)")
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "GET"
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("2024-11-05", forHTTPHeaderField: "MCP-Protocol-Version")
        request.timeoutInterval = 30
        
        let settings = SettingsManager.shared
        if settings.mcpUseAuth && !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MCPError.invalidResponse
        }
        
        // Parse session endpoint
        guard let endpoint = try await parseSessionEndpoint(from: bytes) else {
            throw MCPError.invalidResponse
        }
        
        print("✅ Got tool call session: \(endpoint)")
        
        // Build messages URL
        var baseURLString = sseURL
        if baseURLString.hasSuffix("/sse") {
            baseURLString = String(baseURLString.dropLast(4))
        }
        
        guard let baseURL = URL(string: baseURLString) else {
            throw MCPError.invalidURL
        }
        
        let fullURL = "\(baseURL.scheme ?? "http")://\(baseURL.host ?? ""):\(baseURL.port ?? 8123)\(endpoint.trimmingCharacters(in: .whitespaces))"
        guard let messagesURL = URL(string: fullURL) else {
            throw MCPError.invalidURL
        }
        
        // Initialize MCP session (required before tool calls)
        let initID = UUID().uuidString
        let initJSON = """
        {
            "jsonrpc": "2.0",
            "method": "initialize",
            "id": "\(initID)",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {
                    "name": "MCP iOS Client",
                    "version": "1.0"
                }
            }
        }
        """
        
        var initRequest = URLRequest(url: messagesURL)
        initRequest.httpMethod = "POST"
        initRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        initRequest.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        initRequest.setValue("2024-11-05", forHTTPHeaderField: "MCP-Protocol-Version")
        initRequest.timeoutInterval = 30
        
        if settings.mcpUseAuth && !accessToken.isEmpty {
            initRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        initRequest.httpBody = initJSON.data(using: .utf8)
        let (_, initResponse) = try await URLSession.shared.data(for: initRequest)
        guard let httpInitResponse = initResponse as? HTTPURLResponse,
              (200...299).contains(httpInitResponse.statusCode) else {
            throw MCPError.httpError((initResponse as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        // Read initialize response from SSE (skip for now)
        // Then send notifications/initialized
        let notifJSON = """
        {
            "jsonrpc": "2.0",
            "method": "notifications/initialized",
            "params": {}
        }
        """
        
        var notifRequest = URLRequest(url: messagesURL)
        notifRequest.httpMethod = "POST"
        notifRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        notifRequest.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        notifRequest.setValue("2024-11-05", forHTTPHeaderField: "MCP-Protocol-Version")
        notifRequest.timeoutInterval = 10
        
        if settings.mcpUseAuth && !accessToken.isEmpty {
            notifRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        notifRequest.httpBody = notifJSON.data(using: .utf8)
        let (_, notifResponse) = try await URLSession.shared.data(for: notifRequest)
        guard let httpNotifResponse = notifResponse as? HTTPURLResponse,
              (200...299).contains(httpNotifResponse.statusCode) else {
            throw MCPError.httpError((notifResponse as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        // Send tools/call request
        let requestID = UUID().uuidString
        
        // Build the complete JSON-RPC request with proper argument encoding
        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "tools/call",
            "id": requestID,
            "params": [
                "name": name,
                "arguments": arguments
            ] as [String : Any]
        ]
        
        // Debug: print the request body that will be sent
        if let jsonData = try? JSONSerialization.data(withJSONObject: requestBody),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 Tool call request body: \(jsonString)")
        }
        
        var messagesRequest = URLRequest(url: messagesURL)
        messagesRequest.httpMethod = "POST"
        messagesRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        messagesRequest.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        messagesRequest.setValue("2024-11-05", forHTTPHeaderField: "MCP-Protocol-Version")
        messagesRequest.timeoutInterval = 30
        
        if settings.mcpUseAuth && !accessToken.isEmpty {
            messagesRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        messagesRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        let (_, toolsResponse) = try await URLSession.shared.data(for: messagesRequest)
        
        guard let httpToolsResponse = toolsResponse as? HTTPURLResponse,
              (200...299).contains(httpToolsResponse.statusCode) else {
            throw MCPError.httpError((toolsResponse as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        // Read response from SSE
        print("📡 Reading tool call response from SSE stream...")
        var toolsDataBuffer = Data()
        var toolsLastLineIndex = 0
        var toolsWaitingForMessage = false
        var responseData: String?
        var bytesRead = 0
        
        for try await byte in bytes.prefix(32768) {
            toolsDataBuffer.append(byte)
            bytesRead += 1
            
            if let partialString = String(data: toolsDataBuffer, encoding: .utf8) {
                let lines = partialString.components(separatedBy: .newlines)
                
                if lines.count <= toolsLastLineIndex {
                    continue
                }
                
                for index in toolsLastLineIndex..<(lines.count - 1) {
                    let line = lines[index].trimmingCharacters(in: .whitespaces)
                    
                    if toolsWaitingForMessage {
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))
                            if data.contains("\"id\":\"\(requestID)\"") {
                                responseData = data
                                print("✅ Received tool call response")
                                break
                            }
                        }
                    } else if line == "event: message" {
                        print("📍 Found event: message in SSE stream")
                        toolsWaitingForMessage = true
                    }
                }
                
                toolsLastLineIndex = lines.count - 1
                
                if responseData != nil {
                    break
                }
            }
            
            if toolsDataBuffer.count > 16384 {
                print("⚠️ SSE buffer exceeded 16KB limit")
                break
            }
            
            // Timeout after reading a reasonable amount
            if bytesRead > 4096 && toolsDataBuffer.isEmpty {
                print("⚠️ No data received from SSE stream after 4KB")
                break
            }
        }
        
        print("📊 Read \(bytesRead) bytes from SSE stream")
        
        guard let responseData = responseData else {
            print("❌ No response found in SSE stream")
            throw MCPError.invalidResponse
        }
        
        print("📄 Tool call response: \(responseData.prefix(500))")
        
        guard let jsonData = responseData.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            print("❌ Failed to parse response as JSON")
            throw MCPError.invalidResponse
        }
        
        // Extract content from result
        if let result = json["result"] as? [String: Any] {
            if let content = result["content"] as? [[String: Any]] {
                let textItems = content.compactMap { item -> String? in
                    if let type = item["type"] as? String, type == "text",
                       let text = item["text"] as? String {
                        return text
                    }
                    return nil
                }
                let result = textItems.joined(separator: "\n")
                print("✅ Tool call succeeded: \(result)")
                return result
            } else if let message = result["message"] as? String {
                print("✅ Tool call succeeded: \(message)")
                return message
            }
        }
        
        print("✅ Tool call completed (no result content)")
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

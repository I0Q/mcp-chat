//
//  MCPClient.swift
//  HelloWorld
//
//  Clean MCP client - Direct SSE implementation
//

import Foundation

class MCPClient {
    static let shared = MCPClient()
    
    private var cachedTools: [MCPTool] = []
    private var lastMCPConfig: String = ""
    
    private init() {}
    
    // MARK: - Public API
    
    func clearCache() {
        cachedTools.removeAll()
        lastMCPConfig = ""
    }
    
    func fetchTools() async throws -> [MCPTool] {
        let s = SettingsManager.shared
        guard s.mcpEnabled, !s.mcpSSEURL.isEmpty else {
            cachedTools = []
            return []
        }
        
        let config = "\(s.mcpSSEURL)|\(s.mcpAccessToken)|\(s.mcpEnabled)"
        if config != lastMCPConfig {
            cachedTools.removeAll()
        }
        
        if !cachedTools.isEmpty {
            return cachedTools
        }
        
        cachedTools = try await fetchToolsFromServer()
        lastMCPConfig = config
        return cachedTools
    }
    
    func callTool(name: String, arguments: [String: Any]) async throws -> String {
        let s = SettingsManager.shared
        guard s.mcpEnabled, !s.mcpSSEURL.isEmpty else {
            throw MCPError.invalidURL
        }
        return try await callToolOnServer(name: name, arguments: arguments)
    }
    
    // MARK: - Private Implementation
    
    private func fetchToolsFromServer() async throws -> [MCPTool] {
        let (bytes, messagesURL) = try await establishSession()
        
        // MCP handshake: initialize -> notifications/initialized -> tools/list
        try await sendRequest(messagesURL, "initialize", ["protocolVersion": "2024-11-05", "capabilities": [:], "clientInfo": ["name": "MCP iOS Client", "version": "1.0"]], bytes: bytes, expectResponse: true)
        try await sendRequest(messagesURL, "notifications/initialized", [:], bytes: bytes)
        
        let toolsID = UUID().uuidString
        try await sendRequest(messagesURL, "tools/list", [:], id: toolsID, bytes: bytes)
        
        guard let response = try await readSSEResponse(from: bytes, expectedID: toolsID) else {
            return []
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: response.data(using: .utf8)!) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let toolsArray = result["tools"] as? [[String: Any]] else {
            return []
        }
        
        return parseTools(toolsArray)
    }
    
    private func callToolOnServer(name: String, arguments: [String: Any]) async throws -> String {
        let (bytes, messagesURL) = try await establishSession()
        
        // MCP handshake
        try await sendRequest(messagesURL, "initialize", ["protocolVersion": "2024-11-05", "capabilities": [:], "clientInfo": ["name": "MCP iOS Client", "version": "1.0"]], bytes: bytes, expectResponse: true)
        try await sendRequest(messagesURL, "notifications/initialized", [:], bytes: bytes)
        
        // Call tool
        let requestID = UUID().uuidString
        let params: [String: Any] = ["name": name, "arguments": arguments]
        try await sendRequest(messagesURL, "tools/call", params, id: requestID, bytes: bytes)
        
        guard let response = try await readSSEResponse(from: bytes, expectedID: requestID) else {
            throw MCPError.invalidResponse
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: response.data(using: .utf8)!) as? [String: Any],
              let result = json["result"] as? [String: Any] else {
            return "Success"
        }
        
        if let content = result["content"] as? [[String: Any]] {
            return content.compactMap { item -> String? in
                guard item["type"] as? String == "text", let text = item["text"] as? String else { return nil }
                return text
            }.joined(separator: "\n")
        }
        
        return result["message"] as? String ?? "Success"
    }
    
    // MARK: - Helpers
    
    private func establishSession() async throws -> (URLSession.AsyncBytes, URL) {
        let s = SettingsManager.shared
        
        guard let baseURL = URL(string: s.mcpSSEURL) else {
            throw MCPError.invalidURL
        }
        
        let request = try buildSSERequest(url: baseURL)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MCPError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        guard let endpoint = try await parseSessionEndpoint(from: bytes) else {
            throw MCPError.invalidResponse
        }
        
        var baseURLStr = s.mcpSSEURL
        if baseURLStr.hasSuffix("/sse") { baseURLStr = String(baseURLStr.dropLast(4)) }
        
        guard let url = URL(string: baseURLStr), let scheme = url.scheme, let host = url.host else {
            throw MCPError.invalidURL
        }
        
        let port = url.port ?? 8123
        guard let messagesURL = URL(string: "\(scheme)://\(host):\(port)\(endpoint.trimmingCharacters(in: .whitespaces))") else {
            throw MCPError.invalidURL
        }
        
        return (bytes, messagesURL)
    }
    
    private func parseSessionEndpoint(from bytes: URLSession.AsyncBytes) async throws -> String? {
        var buffer = Data()
        var lastIdx = 0
        var waitingForData = false
        
        for try await byte in bytes.prefix(8192) {
            buffer.append(byte)
            guard let str = String(data: buffer, encoding: .utf8) else { continue }
            
            let lines = str.components(separatedBy: .newlines)
            guard lines.count > lastIdx else { continue }
            
            for i in lastIdx..<(lines.count - 1) {
                let line = lines[i].trimmingCharacters(in: .whitespaces)
                
                if waitingForData && line.hasPrefix("data: ") {
                    return String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line == "event: endpoint" {
                    waitingForData = true
                }
            }
            
            lastIdx = lines.count - 1
            if buffer.count > 4096 { break }
        }
        
        return nil
    }
    
    private func readSSEResponse(from bytes: URLSession.AsyncBytes, expectedID: String, maxBytes: Int = 32768) async throws -> String? {
        var buffer = Data()
        var lastIdx = 0
        var waitingForMsg = false
        var responseData: String?
        
        for try await byte in bytes.prefix(maxBytes) {
            buffer.append(byte)
            guard let str = String(data: buffer, encoding: .utf8) else { continue }
            
            let lines = str.components(separatedBy: .newlines)
            guard lines.count > lastIdx else { continue }
            
            for i in lastIdx..<(lines.count - 1) {
                let line = lines[i].trimmingCharacters(in: .whitespaces)
                
                if waitingForMsg && line.hasPrefix("data: ") {
                    let data = String(line.dropFirst(6))
                    if data.contains("\"id\":\"\(expectedID)\"") {
                        responseData = data
                        break
                    }
                } else if line == "event: message" {
                    waitingForMsg = true
                }
            }
            
            lastIdx = lines.count - 1
            if responseData != nil || buffer.count > 16384 { break }
        }
        
        return responseData
    }
    
    private func sendRequest(_ url: URL, _ method: String, _ params: [String: Any], id: String = UUID().uuidString, bytes: URLSession.AsyncBytes? = nil, expectResponse: Bool = false) async throws {
        var request = try createJSONRPCRequest(url: url, method: method, params: params, id: id)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MCPError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        if expectResponse, let bytes = bytes {
            _ = try await readSSEResponse(from: bytes, expectedID: id, maxBytes: 16384)
        }
    }
    
    private func buildSSERequest(url: URL) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("2024-11-05", forHTTPHeaderField: "MCP-Protocol-Version")
        request.timeoutInterval = 30
        
        let s = SettingsManager.shared
        if s.mcpUseAuth && !s.mcpAccessToken.isEmpty {
            request.setValue("Bearer \(s.mcpAccessToken)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    private func createJSONRPCRequest(url: URL, method: String, params: [String: Any], id: String) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("2024-11-05", forHTTPHeaderField: "MCP-Protocol-Version")
        request.timeoutInterval = 30
        
        let s = SettingsManager.shared
        if s.mcpUseAuth && !s.mcpAccessToken.isEmpty {
            request.setValue("Bearer \(s.mcpAccessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = ["jsonrpc": "2.0", "method": method, "id": id, "params": params]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return request
    }
    
    private func parseTools(_ toolsArray: [[String: Any]]) -> [MCPTool] {
        return toolsArray.compactMap { tool in
            guard let name = tool["name"] as? String else { return nil }
            return MCPTool(
                name: name,
                title: tool["title"] as? String,
                description: tool["description"] as? String,
                inputSchema: tool["inputSchema"] as? [String: Any]
            )
        }
    }
    
    enum MCPError: LocalizedError {
        case invalidURL, invalidResponse, httpError(Int)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .invalidResponse: return "Invalid response"
            case .httpError(let code): return "HTTP \(code)"
            }
        }
    }
}

// MARK: - Data Models

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
        inputSchema = try? JSONSerialization.jsonObject(
            with: (try? container.decode(Data.self, forKey: .inputSchema)) ?? Data()
        ) as? [String: Any]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        if let schema = inputSchema {
            if let data = try? JSONSerialization.data(withJSONObject: schema) {
                try container.encode(data, forKey: .inputSchema)
            }
        }
    }
    
    init(name: String, title: String? = nil, description: String?, inputSchema: [String: Any]? = nil) {
        self.name = name
        self.title = title
        self.description = description
        self.inputSchema = inputSchema
    }
}

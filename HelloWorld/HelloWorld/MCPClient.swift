//
//  MCPClient.swift
//  HelloWorld
//
//  MCP client with SSE (Server-Sent Events) streaming support
//

import Foundation

class MCPClient {
    static let shared = MCPClient()
    
    private var sseTask: URLSessionDataTask?
    private var eventListeners: [String: (Data) -> Void] = [:]
    
    private init() {}
    
    // Fetch tools from MCP server via SSE
    func fetchTools(sseURL: String, accessToken: String) async throws -> [MCPTool] {
        // For now, return empty since SSE implementation needs persistent connection
        // This will be implemented with proper SSE streaming
        print("⚠️ SSE streaming implementation in progress")
        print("ℹ️ SSE requires persistent GET connection with event parsing")
        return []
    }
    
    // Call a tool via SSE streaming
    func callTool(toolName: String, arguments: [String: Any], sseURL: String, accessToken: String) async throws -> String {
        print("⚠️ SSE tool execution not yet implemented")
        print("ℹ️ Need to implement:")
        print("   1. Persistent SSE connection")
        print("   2. JSON-RPC message sending")
        print("   3. Event stream parsing")
        return "SSE streaming not yet implemented"
    }
    
    // Start SSE connection (basic framework)
    private func startSSEConnection(url: URL, accessToken: String) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 3600 // Long timeout for streaming
        
        // Create URLSessionDataTask for streaming
        let session = URLSession.shared
        sseTask = session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ SSE connection error: \(error)")
                return
            }
            
            guard let data = data else { return }
            
            // Parse SSE format
            self?.parseSSEMessage(data)
        }
        
        sseTask?.resume()
    }
    
    // Parse SSE message
    private func parseSSEMessage(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        
        // SSE format: "event: name\n" or "data: {...}\n" or "data: {...}\n\n"
        let lines = text.components(separatedBy: "\n")
        var eventName: String?
        var eventData: String?
        
        for line in lines {
            if line.hasPrefix("event: ") {
                eventName = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data: ") {
                eventData = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.isEmpty {
                // End of message
                if let name = eventName, let data = eventData {
                    handleSSEEvent(name: name, data: data)
                }
                eventName = nil
                eventData = nil
            }
        }
    }
    
    // Handle SSE event
    private func handleSSEEvent(name: String, data: String) {
        print("📡 SSE Event: \(name)")
        
        if let listener = eventListeners[name] {
            guard let jsonData = data.data(using: .utf8) else { return }
            listener(jsonData)
        }
    }
    
    // Send message through SSE (placeholder)
    private func sendSSEMessage(_ message: [String: Any]) async throws {
        print("⚠️ Sending messages through SSE not yet implemented")
        // This requires a way to send data through the SSE connection
        // Most SSE implementations are one-way (server to client)
        // Would need WebSocket or separate POST endpoint
    }
    
    // Cancel SSE connection
    func cancelConnection() {
        sseTask?.cancel()
        sseTask = nil
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
                return "Invalid response from MCP server"
            case .httpError(let code):
                return "HTTP Error: \(code)"
            }
        }
    }
}

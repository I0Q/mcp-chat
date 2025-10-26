//
//  MCPClient.swift
//  HelloWorld
//
//  MCP client using WebSocket for bidirectional communication
//

import Foundation

class MCPClient {
    static let shared = MCPClient()
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var pendingRequests: [String: CheckedContinuation<[String: Any], Error>] = [:]
    
    private init() {}
    
    // Connect to MCP server via WebSocket
    private func connectWebSocket(url: URL, accessToken: String) async throws {
        let session = URLSession(configuration: .default)
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Start receiving messages
        await receiveMessages()
        
        print("✅ WebSocket connected to MCP server")
    }
    
    // Receive messages from WebSocket
    private func receiveMessages() async {
        guard let webSocketTask = webSocketTask else { return }
        
        do {
            let message = try await webSocketTask.receive()
            
            switch message {
            case .string(let text):
                handleWebSocketMessage(text)
            case .data(let data):
                if let text = String(data: data, encoding: .utf8) {
                    handleWebSocketMessage(text)
                }
            @unknown default:
                break
            }
            
            // Continue receiving
            await receiveMessages()
            
        } catch {
            print("❌ WebSocket receive error: \(error)")
        }
    }
    
    // Handle incoming WebSocket message
    private func handleWebSocketMessage(_ text: String) {
        print("📨 Received: \(text)")
        
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else {
            return
        }
        
        // Resolve the pending request
        if let continuation = pendingRequests[id] {
            continuation.resume(returning: json)
            pendingRequests.removeValue(forKey: id)
        }
    }
    
    // Send WebSocket message
    private func sendWebSocketMessage(_ message: [String: Any]) async throws {
        guard let webSocketTask = webSocketTask else {
            throw MCPError.notConnected
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw MCPError.invalidURL
        }
        
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        try await webSocketTask.send(message)
    }
    
    // Fetch tools from MCP server
    func fetchTools(sseURL: String, accessToken: String) async throws -> [MCPTool] {
        // Convert SSE URL to WebSocket URL
        guard let sseURLObj = URL(string: sseURL) else {
            throw MCPError.invalidURL
        }
        
        // Convert http:// to ws:// and https:// to wss://
        var wsURL = sseURL.replacingOccurrences(of: "http://", with: "ws://")
        wsURL = wsURL.replacingOccurrences(of: "https://", with: "wss://")
        wsURL = wsURL.replacingOccurrences(of: "/mcp_server/sse", with: "/mcp_server/ws")
        
        guard let url = URL(string: wsURL) else {
            throw MCPError.invalidURL
        }
        
        print("🔗 Connecting to MCP WebSocket: \(wsURL)")
        
        // Connect if not already connected
        if webSocketTask == nil {
            try await connectWebSocket(url: url, accessToken: accessToken)
        }
        
        // Send tools/list request
        let requestId = UUID().uuidString
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": requestId,
            "params": [:]
        ]
        
        // Use continuation to wait for response
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[requestId] = continuation
            
            Task {
                do {
                    try await self.sendWebSocketMessage(request)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            // Timeout after 5 seconds
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if pendingRequests[requestId] != nil {
                    pendingRequests.removeValue(forKey: requestId)
                    continuation.resume(throwing: MCPError.timeout)
                }
            }
        }
    }
    
    // Call a tool via WebSocket
    func callTool(toolName: String, arguments: [String: Any], sseURL: String, accessToken: String) async throws -> String {
        // Similar to fetchTools but for tools/call
        print("🔧 Calling tool via WebSocket: \(toolName)")
        
        let requestId = UUID().uuidString
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "tools/call",
            "id": requestId,
            "params": [
                "name": toolName,
                "arguments": arguments
            ]
        ]
        
        // Send and wait for response
        let response = try await withCheckedThrowingContinuation { continuation in
            pendingRequests[requestId] = continuation
            
            Task {
                do {
                    try await sendWebSocketMessage(request)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if pendingRequests[requestId] != nil {
                    pendingRequests.removeValue(forKey: requestId)
                    continuation.resume(throwing: MCPError.timeout)
                }
            }
        } as? [String: Any]
        
        guard let result = response?["result"] as? [String: Any] else {
            throw MCPError.invalidResponse
        }
        
        // Extract content
        if let content = result["content"] as? [[String: Any]] {
            let textItems = content.compactMap { item -> String? in
                if let type = item["type"] as? String, type == "text",
                   let text = item["text"] as? String {
                    return text
                }
                return nil
            }
            return textItems.joined(separator: "\n")
        }
        
        return "Success"
    }
    
    // Close WebSocket connection
    func close() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }
    
    enum MCPError: LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(Int)
        case notConnected
        case timeout
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response from MCP server"
            case .httpError(let code):
                return "HTTP Error: \(code)"
            case .notConnected:
                return "Not connected to MCP server"
            case .timeout:
                return "Request timeout"
            }
        }
    }
}

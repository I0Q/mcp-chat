//
//  MCPClient.swift
//  HelloWorld
//
//  MCP client supporting mcp-proxy for SSE transport
//

import Foundation

class MCPClient {
    static let shared = MCPClient()
    
    private init() {}
    
    // Fetch tools from MCP server
    // Supports both direct SSE and mcp-proxy stdio transport
    func fetchTools(sseURL: String, accessToken: String) async throws -> [MCPTool] {
        // Check if we should use mcp-proxy
        let useProxy = shouldUseProxy()
        
        if useProxy {
            print("🔗 Using mcp-proxy for MCP transport")
            return try await fetchToolsViaProxy()
        }
        
        // For direct SSE (complex, not implemented yet)
        print("⚠️ Direct SSE not implemented")
        print("💡 Use mcp-proxy or wait for full SSE client")
        return []
    }
    
    // Call a tool on MCP server
    func callTool(toolName: String, arguments: [String: Any], sseURL: String, accessToken: String) async throws -> String {
        let useProxy = shouldUseProxy()
        
        if useProxy {
            print("🔗 Using mcp-proxy for tool execution")
            return try await callToolViaProxy(name: toolName, arguments: arguments)
        }
        
        print("⚠️ Tool execution not implemented for direct SSE")
        return "Tool execution requires mcp-proxy configuration"
    }
    
    private func shouldUseProxy() -> Bool {
        // For now, always suggest using proxy
        // In production, check if mcp-proxy is configured
        return false // Change to true when proxy is configured
    }
    
    private func fetchToolsViaProxy() async throws -> [MCPTool] {
        print("ℹ️ mcp-proxy integration not yet implemented")
        print("💡 To add mcp-proxy support:")
        print("   1. Run mcp-proxy locally")
        print("   2. Connect via stdio transport")
        print("   3. Send JSON-RPC messages")
        return []
    }
    
    private func callToolViaProxy(name: String, arguments: [String: Any]) async throws -> String {
        print("ℹ️ mcp-proxy tool execution not yet implemented")
        return "Please implement mcp-proxy stdio connection"
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

//
//  MCPClient.swift
//  HelloWorld
//
//  Generic MCP client using Server-Sent Events (SSE) transport
//

import Foundation

class MCPClient {
    static let shared = MCPClient()
    
    private init() {}
    
    // Fetch tools from MCP server
    // Returns empty array if server doesn't expose tools via standard endpoint
    func fetchTools(sseURL: String, accessToken: String) async throws -> [MCPTool] {
        print("⚠️ Tool discovery not implemented for generic MCP servers")
        print("ℹ️ Returning empty array - tools will be defined by the LLM's knowledge")
        return []
    }
    
    // Call a tool - MCP servers handle tool execution differently
    // For now, we'll rely on the LLM to know what tools are available
    func callTool(toolName: String, arguments: [String: Any], sseURL: String, accessToken: String) async throws -> String {
        print("⚠️ Tool execution not implemented for generic MCP servers")
        print("ℹ️ LLM should handle tool calls via its knowledge of the MCP server")
        return "Tool execution not supported in generic mode"
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

//
//  MCPClient.swift
//  HelloWorld
//
//  MCP is handled by the LLM server
//  No client-side MCP implementation needed
//

import Foundation

class MCPClient {
    static let shared = MCPClient()
    
    private init() {}
    
    // No-op: MCP is handled server-side by the LLM
    func fetchTools(sseURL: String, accessToken: String) async throws -> [MCPTool] {
        print("ℹ️ MCP is handled server-side by the LLM at 192.168.1.232")
        print("💡 Tools are automatically available in chat")
        return []
    }
    
    // No-op: MCP is handled server-side
    func callTool(toolName: String, arguments: [String: Any], sseURL: String, accessToken: String) async throws -> String {
        print("ℹ️ Tool execution is handled by the LLM server")
        return "Tool execution handled by LLM"
    }
    
    enum MCPError: LocalizedError {
        case invalidURL
        
        var errorDescription: String? {
            return "Invalid URL"
        }
    }
}

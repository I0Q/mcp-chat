//
//  MCPServerConfig.swift
//  HelloWorld
//
//  Model for MCP server configuration
//

import Foundation

struct MCPServerConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var sseURL: String
    var accessToken: String
    var useAuth: Bool
    var enabled: Bool
    
    init(id: UUID = UUID(), name: String, sseURL: String, accessToken: String = "", useAuth: Bool = false, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.sseURL = sseURL
        self.accessToken = accessToken
        self.useAuth = useAuth
        self.enabled = enabled
    }
}

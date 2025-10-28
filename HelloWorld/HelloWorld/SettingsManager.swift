//
//  SettingsManager.swift
//  HelloWorld
//
//  Created by Acacio Santana on 10/26/25.
//

import Foundation
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var serverURL: String {
        didSet {
            UserDefaults.standard.set(serverURL, forKey: "serverURL")
        }
    }
    
    @Published var selectedModel: String {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "selectedModel")
        }
    }
    
    @Published var thinkingEffort: String {
        didSet {
            UserDefaults.standard.set(thinkingEffort, forKey: "thinkingEffort")
        }
    }
    
    @Published var thinkingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(thinkingEnabled, forKey: "thinkingEnabled")
        }
    }
    
    @Published var mcpEnabled: Bool {
        didSet {
            UserDefaults.standard.set(mcpEnabled, forKey: "mcpEnabled")
        }
    }
    
    @Published var mcpServerName: String {
        didSet {
            UserDefaults.standard.set(mcpServerName, forKey: "mcpServerName")
        }
    }
    
    @Published var mcpSSEURL: String {
        didSet {
            UserDefaults.standard.set(mcpSSEURL, forKey: "mcpSSEURL")
            if oldValue != mcpSSEURL {
                MCPClient.shared.clearCache()
            }
        }
    }
    
    @Published var mcpAccessToken: String {
        didSet {
            UserDefaults.standard.set(mcpAccessToken, forKey: "mcpAccessToken")
            // Only clear cache if the value actually changed
            if oldValue != mcpAccessToken {
                MCPClient.shared.clearCache()
            }
        }
    }
    
    @Published var mcpUseAuth: Bool {
        didSet {
            UserDefaults.standard.set(mcpUseAuth, forKey: "mcpUseAuth")
            if oldValue != mcpUseAuth {
                MCPClient.shared.clearCache()
            }
        }
    }
    
    
    @Published var voiceEnabled: Bool {
        didSet {
            UserDefaults.standard.set(voiceEnabled, forKey: "voiceEnabled")
        }
    }
    
    @Published var voiceServiceURL: String {
        didSet {
            UserDefaults.standard.set(voiceServiceURL, forKey: "voiceServiceURL")
        }
    }
    
    @Published var voiceServiceType: String {
        didSet {
            UserDefaults.standard.set(voiceServiceType, forKey: "voiceServiceType")
        }
    }
    
    @Published var showMCPInReasoning: Bool {
        didSet {
            UserDefaults.standard.set(showMCPInReasoning, forKey: "showMCPInReasoning")
        }
    }
    
    @Published var mcpServers: [MCPServerConfig] {
        didSet {
            if let encoded = try? JSONEncoder().encode(mcpServers) {
                UserDefaults.standard.set(encoded, forKey: "mcpServers")
            }
        }
    }
    
    private init() {
        self.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://192.168.1.232:1234"
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "openai/gpt-oss-20b"
        self.thinkingEffort = UserDefaults.standard.string(forKey: "thinkingEffort") ?? "medium"
        self.thinkingEnabled = UserDefaults.standard.bool(forKey: "thinkingEnabled")
        
        self.mcpEnabled = UserDefaults.standard.bool(forKey: "mcpEnabled")
        self.mcpServerName = UserDefaults.standard.string(forKey: "mcpServerName") ?? ""
        self.mcpSSEURL = UserDefaults.standard.string(forKey: "mcpSSEURL") ?? ""
        self.mcpAccessToken = UserDefaults.standard.string(forKey: "mcpAccessToken") ?? ""
        self.mcpUseAuth = UserDefaults.standard.bool(forKey: "mcpUseAuth")
        
        self.voiceEnabled = UserDefaults.standard.bool(forKey: "voiceEnabled")
        self.voiceServiceURL = UserDefaults.standard.string(forKey: "voiceServiceURL") ?? "http://192.168.1.232:8005"
        self.voiceServiceType = UserDefaults.standard.string(forKey: "voiceServiceType") ?? "openai-whisper"
        self.showMCPInReasoning = UserDefaults.standard.bool(forKey: "showMCPInReasoning")
        
        // Initialize mcpServers first
        self.mcpServers = []
        
        // Migrate old model names
        if selectedModel == "gpt-oss-120b" {
            UserDefaults.standard.set("openai/gpt-oss-120b", forKey: "selectedModel")
            self.selectedModel = "openai/gpt-oss-120b"
        }
        
        // Initialize or migrate MCP servers
        if let data = UserDefaults.standard.data(forKey: "mcpServers"),
           let decodedServers = try? JSONDecoder().decode([MCPServerConfig].self, from: data) {
            self.mcpServers = decodedServers
        } else {
            // Migrate from old single-server setup
            let oldServerName = UserDefaults.standard.string(forKey: "mcpServerName") ?? "Main MCP Server"
            let oldSSEURL = UserDefaults.standard.string(forKey: "mcpSSEURL") ?? ""
            let oldAccessToken = UserDefaults.standard.string(forKey: "mcpAccessToken") ?? ""
            let oldUseAuth = UserDefaults.standard.bool(forKey: "mcpUseAuth")
            let oldEnabled = UserDefaults.standard.bool(forKey: "mcpEnabled")
            let oldSelectedTools = UserDefaults.standard.array(forKey: "selectedTools") as? [String] ?? []
            
            if !oldSSEURL.isEmpty {
                let server = MCPServerConfig(
                    name: oldServerName,
                    sseURL: oldSSEURL,
                    accessToken: oldAccessToken,
                    useAuth: oldUseAuth,
                    enabled: oldEnabled,
                    selectedTools: oldSelectedTools
                )
                self.mcpServers.append(server)
            }
            
            // Save migrated data
            if let encoded = try? JSONEncoder().encode(self.mcpServers) {
                UserDefaults.standard.set(encoded, forKey: "mcpServers")
            }
        }
    }
    
    // Helper methods for managing MCP servers
    func addMCPServer(_ server: MCPServerConfig) {
        mcpServers.append(server)
    }
    
    func updateMCPServer(_ server: MCPServerConfig) {
        if let index = mcpServers.firstIndex(where: { $0.id == server.id }) {
            mcpServers[index] = server
        }
    }
    
    func deleteMCPServer(_ server: MCPServerConfig) {
        mcpServers.removeAll(where: { $0.id == server.id })
        MCPClient.shared.clearCache(for: server.id)
    }
    
    func getEnabledMCPServers() -> [MCPServerConfig] {
        return mcpServers.filter { $0.enabled }
    }
}


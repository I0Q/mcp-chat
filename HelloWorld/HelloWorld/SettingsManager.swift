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
        }
    }
    
    @Published var mcpAccessToken: String {
        didSet {
            UserDefaults.standard.set(mcpAccessToken, forKey: "mcpAccessToken")
        }
    }
    
    @Published var mcpProxyURL: String {
        didSet {
            UserDefaults.standard.set(mcpProxyURL, forKey: "mcpProxyURL")
        }
    }
    
    private init() {
        self.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://192.168.1.232:1234"
        self.mcpEnabled = UserDefaults.standard.bool(forKey: "mcpEnabled")
        
        // Set default MCP values if not already configured
        self.mcpServerName = UserDefaults.standard.string(forKey: "mcpServerName") ?? "Home Assistant"
        self.mcpSSEURL = UserDefaults.standard.string(forKey: "mcpSSEURL") ?? "http://homeassistant:8123/mcp_server/sse"
        self.mcpAccessToken = UserDefaults.standard.string(forKey: "mcpAccessToken") ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIwZjA1M2JjZWRjNzk0NTlmOGZjMTQ3ZWYwZDVhZWM4MCIsImlhdCI6MTc2MTQ5NDQwNiwiZXhwIjoyMDc2ODU0NDA2fQ.PSwfpbey4BXe2TmScH5PxVMhgOVsjVqU8sdx5twQjZU"
        // Use LLM server URL as the mcp-proxy endpoint (since mcp-proxy runs there)
        self.mcpProxyURL = UserDefaults.standard.string(forKey: "mcpProxyURL") ?? ""
        
        // Save defaults if they don't exist
        if UserDefaults.standard.string(forKey: "mcpServerName") == nil {
            UserDefaults.standard.set("Home Assistant", forKey: "mcpServerName")
        }
        if UserDefaults.standard.string(forKey: "mcpSSEURL") == nil {
            UserDefaults.standard.set("http://homeassistant:8123/mcp_server/sse", forKey: "mcpSSEURL")
        }
        if UserDefaults.standard.string(forKey: "mcpAccessToken") == nil {
            UserDefaults.standard.set("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIwZjA1M2JjZWRjNzk0NTlmOGZjMTQ3ZWYwZDVhZWM4MCIsImlhdCI6MTc2MTQ5NDQwNiwiZXhwIjoyMDc2ODU0NDA2fQ.PSwfpbey4BXe2TmScH5PxVMhgOVsjVqU8sdx5twQjZU", forKey: "mcpAccessToken")
        }
        
        self.thinkingEffort = UserDefaults.standard.string(forKey: "thinkingEffort") ?? "medium"
        self.thinkingEnabled = UserDefaults.standard.bool(forKey: "thinkingEnabled")
        
        // Migrate old model names to new format
        if let savedModel = UserDefaults.standard.string(forKey: "selectedModel") {
            if savedModel == "gpt-oss-120b" {
                self.selectedModel = "openai/gpt-oss-120b"
            } else {
                self.selectedModel = savedModel
            }
        } else {
            self.selectedModel = "openai/gpt-oss-20b"
        }
    }
}


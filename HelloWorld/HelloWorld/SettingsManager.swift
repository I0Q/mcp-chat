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
    
    @Published var mcpUseAuth: Bool {
        didSet {
            UserDefaults.standard.set(mcpUseAuth, forKey: "mcpUseAuth")
        }
    }
    
    @Published var selectedTools: [String] {
        didSet {
            UserDefaults.standard.set(selectedTools, forKey: "selectedTools")
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
        self.selectedTools = UserDefaults.standard.array(forKey: "selectedTools") as? [String] ?? []
        
        // Migrate old model names
        if selectedModel == "gpt-oss-120b" {
            UserDefaults.standard.set("openai/gpt-oss-120b", forKey: "selectedModel")
            self.selectedModel = "openai/gpt-oss-120b"
        }
    }
}


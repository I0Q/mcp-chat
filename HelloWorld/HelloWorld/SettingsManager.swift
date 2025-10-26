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
    
    private init() {
        self.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://192.168.1.232:1234"
        self.mcpEnabled = UserDefaults.standard.bool(forKey: "mcpEnabled")
        self.mcpServerName = UserDefaults.standard.string(forKey: "mcpServerName") ?? ""
        self.mcpSSEURL = UserDefaults.standard.string(forKey: "mcpSSEURL") ?? ""
        self.mcpAccessToken = UserDefaults.standard.string(forKey: "mcpAccessToken") ?? ""
        
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


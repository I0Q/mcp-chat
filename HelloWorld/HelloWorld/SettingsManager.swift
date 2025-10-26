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
    
    private init() {
        self.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://192.168.1.232:1234"
        
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


//
//  SettingsView.swift
//  HelloWorld
//
//  Created by Acacio Santana on 10/26/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        Form {
            Section(header: Text("LLM Server Configuration"), footer: Text("Configure your local LLM server connection")) {
                TextField("Server URL", text: $settings.serverURL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                
                Picker("Model", selection: $settings.selectedModel) {
                    Text("openai/gpt-oss-120b").tag("openai/gpt-oss-120b")
                    Text("openai/gpt-oss-20b").tag("openai/gpt-oss-20b")
                }
                
                Toggle("Enable Thinking Mode", isOn: $settings.thinkingEnabled)
                
                if settings.thinkingEnabled {
                    Picker("Thinking Effort", selection: $settings.thinkingEffort) {
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                    }
                }
            }
            
            Section(header: Text("MCP Server Configuration"), footer: Text("Model Context Protocol for tool use and agent capabilities")) {
                Toggle("Enable MCP", isOn: $settings.mcpEnabled)
                
                if settings.mcpEnabled {
                    TextField("Server Name", text: $settings.mcpServerName)
                        .autocapitalization(.none)
                    
                    TextField("MCP SSE URL", text: $settings.mcpSSEURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Toggle("Use Authentication", isOn: $settings.mcpUseAuth)
                    
                    if settings.mcpUseAuth {
                        SecureField("Access Token", text: $settings.mcpAccessToken)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    NavigationLink(destination: ToolDiscoveryView()) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Discover & Select Tools")
                            Spacer()
                            if !settings.selectedTools.isEmpty {
                                Text("(\(settings.selectedTools.count))")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Toggle("Show MCP Tools in Reasoning", isOn: $settings.showMCPInReasoning)
                }
            }
            
            Section(header: Text("Voice Transcription"), footer: Text("Enable voice input with speech-to-text transcription")) {
                Toggle("Enable Voice Input", isOn: $settings.voiceEnabled)
                
                if settings.voiceEnabled {
                    Picker("Service Type", selection: $settings.voiceServiceType) {
                        Text("OpenAI Whisper").tag("openai-whisper")
                        Text("Custom API").tag("custom-api")
                    }
                    
                    TextField("Transcription Service URL", text: $settings.voiceServiceURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                    
                    Text("Default: http://192.168.1.232:8005")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Information"), footer: Text("Version 1.0")) {
                HStack {
                    Text("Server Status")
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.green)
                            .font(.caption2)
                        Text("Connected")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            
            Section(header: Text("About")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chat with your local LLM")
                        .font(.body)
                    Text("Features: MCP tools, voice input, thinking tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.headline)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Settings Saved", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onChange(of: settings.serverURL) {
                guard let url = URL(string: settings.serverURL), url.scheme != nil else {
                    alertMessage = "Invalid URL format"
                    showAlert = true
                    return
                }
            }
            .onChange(of: settings.mcpEnabled) {
                if settings.mcpEnabled {
                    alertMessage = "MCP enabled!"
                    showAlert = true
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}

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
            Section(header: Text("LLM Server Configuration")) {
                TextField("Server URL", text: $settings.serverURL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
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
            
            Section(header: Text("MCP Server Configuration")) {
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
                }
            }
            
            Section(header: Text("Information")) {
                HStack {
                    Text("Server Status")
                    Spacer()
                    Image(systemName: "circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Connected")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("About")) {
                Text("Chat with your local LLM")
                    .font(.caption)
                    .foregroundColor(.secondary)
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


#Preview {
    NavigationView {
        SettingsView()
    }
}

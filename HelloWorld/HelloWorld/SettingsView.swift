//
//  SettingsView.swift
//  HelloWorld
//
//  Created by Acacio Santana on 10/26/25.
//

import SwiftUI
import LocalAuthentication

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showTokenInput = false
    @State private var tokenInput = ""
    @State private var showToken = false
    @State private var authenticatedToken = ""
    @State private var cachedToken = ""
    
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
                        Button(action: {
                            print("🔑 Button tapped - opening token sheet")
                            // Cache the token value and reset state
                            cachedToken = settings.mcpAccessToken
                            tokenInput = cachedToken
                            showToken = false // Reset show state
                            print("🔑 Setting showTokenInput to true")
                            showTokenInput = true
                            print("🔑 showTokenInput: \(showTokenInput)")
                        }) {
                            HStack {
                                Image(systemName: "key.fill")
                                Text(settings.mcpAccessToken.isEmpty ? "Set Access Token" : "Update Access Token")
                                Spacer()
                                if !settings.mcpAccessToken.isEmpty {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
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
                        .placeholder(when: settings.voiceServiceURL.isEmpty) {
                            Text("e.g., http://192.168.1.232:8005")
                                .foregroundColor(.secondary)
                        }
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
            .sheet(isPresented: $showTokenInput) {
                print("📄 Sheet body is rendering")
                return NavigationStack {
                    Form {
                        Section(header: Text("Access Token")) {
                            SecureField("Token", text: $tokenInput)
                        }
                        
                        HStack {
                            Button("Cancel") {
                                showTokenInput = false
                            }
                            Spacer()
                            Button("Save") {
                                settings.mcpAccessToken = tokenInput
                                showTokenInput = false
                            }
                        }
                        .padding()
                    }
                    .navigationTitle("Token")
                    .presentationDetents([.medium])
                }
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
    
    private func authenticateAndShowToken() {
        if showToken {
            // Simply hide the token
            showToken = false
            authenticatedToken = ""
        } else {
            // Authenticate with Face ID or Touch ID
            let context = LAContext()
            context.localizedCancelTitle = "Cancel"
            
            var error: NSError?
            
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                let reason = "Please authenticate to view your access token"
                
                Task {
                    do {
                        let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                        
                        await MainActor.run {
                            if success {
                                showToken = true
                                authenticatedToken = cachedToken
                            }
                        }
                    } catch {
                        await MainActor.run {
                            alertMessage = "Authentication failed: \(error.localizedDescription)"
                            showAlert = true
                        }
                    }
                }
            } else {
                // Fallback if biometrics not available
                showToken = true
                authenticatedToken = cachedToken
            }
        }
    }
}

// View extension for placeholder support
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}

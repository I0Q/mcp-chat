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
    @State private var showAddServer = false
    @State private var newServer: MCPServerConfig?
    
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
                    ForEach($settings.mcpServers) { $server in
                        NavigationLink(destination: MCPServerEditView(serverID: server.id)) {
                            HStack {
                                if server.enabled {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                                Text(server.name)
                                    .foregroundColor(server.enabled ? .primary : .secondary)
                                Spacer()
                            }
                        }
                    }
                    
                    Button(action: {
                        newServer = MCPServerConfig(
                            name: "New MCP Server",
                            sseURL: "",
                            accessToken: "",
                            useAuth: false,
                            enabled: true
                        )
                        showAddServer = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add MCP Server")
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
            .sheet(isPresented: $showAddServer) {
                if let newServer = newServer {
                    MCPServerAddView(newServer: newServer) { savedServer in
                        settings.addMCPServer(savedServer)
                        self.newServer = nil
                    } onCancel: {
                        self.newServer = nil
                    }
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
                                authenticatedToken = settings.mcpAccessToken
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
                authenticatedToken = settings.mcpAccessToken
            }
        }
    }
}

struct MCPServerEditView: View {
    let serverID: UUID
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showTokenInput = false
    @State private var tokenInput = ""
    @State private var showToken = false
    @State private var cachedToken = ""
    @State private var showDeleteConfirmation = false
    
    private var server: MCPServerConfig? {
        settings.mcpServers.first { $0.id == serverID }
    }
    
    var body: some View {
        Group {
            if let server = server {
                Form {
                    Section(header: Text("Server Details"), footer: Text("Configure your MCP server connection")) {
                        TextField("Server Name", text: Binding(
                            get: { server.name },
                            set: { newValue in updateServer { $0.name = newValue } }
                        ))
                        .autocapitalization(.none)
                        
                        TextField("MCP SSE URL", text: Binding(
                            get: { server.sseURL },
                            set: { newValue in updateServer { $0.sseURL = newValue } }
                        ))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        
                        Toggle("Enable Server", isOn: Binding(
                            get: { server.enabled },
                            set: { newValue in updateServer { $0.enabled = newValue } }
                        ))
                        
                        Toggle("Use Authentication", isOn: Binding(
                            get: { server.useAuth },
                            set: { newValue in updateServer { $0.useAuth = newValue } }
                        ))
                    }
                    
                    if server.useAuth {
                        Section(header: Text("Authentication")) {
                            Button(action: {
                                cachedToken = server.accessToken
                                tokenInput = server.accessToken
                                showTokenInput = true
                            }) {
                                HStack {
                                    Image(systemName: "key.fill")
                                    Text(server.accessToken.isEmpty ? "Set Access Token" : "Update Access Token")
                                    Spacer()
                                    if !server.accessToken.isEmpty {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                    }
                    
                    Section(header: Text("Tools")) {
                        NavigationLink(destination: ToolDiscoveryView(serverConfig: server)) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Discover & Select Tools")
                                Spacer()
                                if !server.selectedTools.isEmpty {
                                    Text("(\(server.selectedTools.count))")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Section(header: Text("Danger Zone")) {
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                                Text("Delete Server")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Edit MCP Server")
                .navigationBarTitleDisplayMode(.inline)
                .alert("Delete Server", isPresented: $showDeleteConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        settings.deleteMCPServer(server)
                        dismiss()
                    }
                } message: {
                    Text("Are you sure you want to delete \(server.name)? This action cannot be undone.")
                }
                .sheet(isPresented: $showTokenInput) {
                    NavigationStack {
                        Form {
                            Section(header: Text("Access Token"), footer: Text("Enter your MCP server access token")) {
                                if showToken {
                                    Text(cachedToken)
                                        .font(.system(.body, design: .monospaced))
                                        .textSelection(.enabled)
                                } else {
                                    SecureField("Token", text: $tokenInput)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                            }
                            
                            Section {
                                Button(action: {
                                    authenticateAndShowToken()
                                }) {
                                    HStack {
                                        Image(systemName: showToken ? "eye.slash.fill" : "eye.fill")
                                        Text(showToken ? "Hide Token" : "Show Token")
                                    }
                                }
                            }
                        }
                        .navigationTitle("Access Token")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    showTokenInput = false
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    updateServer { $0.accessToken = tokenInput }
                                    showTokenInput = false
                                }
                            }
                        }
                        .presentationDetents([.medium])
                    }
                }
            } else {
                Text("Server not found")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func updateServer(_ update: (inout MCPServerConfig) -> Void) {
        guard let index = settings.mcpServers.firstIndex(where: { $0.id == serverID }) else { return }
        var updatedServer = settings.mcpServers[index]
        update(&updatedServer)
        settings.updateMCPServer(updatedServer)
    }
    
    private func authenticateAndShowToken() {
        if showToken {
            // Simply hide the token
            showToken = false
            cachedToken = ""
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
                            }
                        }
                    } catch {
                        // Handle error silently
                        print("Authentication failed: \(error.localizedDescription)")
                    }
                }
            } else {
                // Fallback if biometrics not available
                showToken = true
            }
        }
    }
}

struct MCPServerAddView: View {
    @State private var server: MCPServerConfig
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showTokenInput = false
    @State private var tokenInput = ""
    @State private var showToken = false
    @State private var cachedToken = ""
    
    let onSave: (MCPServerConfig) -> Void
    let onCancel: () -> Void
    
    init(newServer: MCPServerConfig, onSave: @escaping (MCPServerConfig) -> Void, onCancel: @escaping () -> Void) {
        _server = State(initialValue: newServer)
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Server Details"), footer: Text("Configure your MCP server connection")) {
                    TextField("Server Name", text: $server.name)
                        .autocapitalization(.none)
                    
                    TextField("MCP SSE URL", text: $server.sseURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                    
                    Toggle("Enable Server", isOn: $server.enabled)
                    
                    Toggle("Use Authentication", isOn: $server.useAuth)
                }
                
                if server.useAuth {
                    Section(header: Text("Authentication")) {
                        Button(action: {
                            cachedToken = server.accessToken
                            tokenInput = server.accessToken
                            showTokenInput = true
                        }) {
                            HStack {
                                Image(systemName: "key.fill")
                                Text(server.accessToken.isEmpty ? "Set Access Token" : "Update Access Token")
                                Spacer()
                                if !server.accessToken.isEmpty {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Tools")) {
                    NavigationLink(destination: ToolDiscoveryView(serverConfig: server)) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Discover & Select Tools")
                            Spacer()
                            if !server.selectedTools.isEmpty {
                                Text("(\(server.selectedTools.count))")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New MCP Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(server)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showTokenInput) {
                NavigationStack {
                    Form {
                        Section(header: Text("Access Token"), footer: Text("Enter your MCP server access token")) {
                            if showToken {
                                Text(cachedToken)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            } else {
                                SecureField("Token", text: $tokenInput)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                        }
                        
                        Section {
                            Button(action: {
                                authenticateAndShowToken()
                            }) {
                                HStack {
                                    Image(systemName: showToken ? "eye.slash.fill" : "eye.fill")
                                    Text(showToken ? "Hide Token" : "Show Token")
                                }
                            }
                        }
                    }
                    .navigationTitle("Access Token")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showTokenInput = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                server.accessToken = tokenInput
                                showTokenInput = false
                            }
                        }
                    }
                    .presentationDetents([.medium])
                }
            }
        }
    }
    
    private func authenticateAndShowToken() {
        if showToken {
            // Simply hide the token
            showToken = false
            cachedToken = ""
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
                            }
                        }
                    } catch {
                        // Handle error silently
                        print("Authentication failed: \(error.localizedDescription)")
                    }
                }
            } else {
                // Fallback if biometrics not available
                showToken = true
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

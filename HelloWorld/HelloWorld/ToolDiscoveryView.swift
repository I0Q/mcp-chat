//
//  ToolDiscoveryView.swift
//  HelloWorld
//
//  Tool discovery and selection screen
//

import SwiftUI

struct ToolDiscoveryView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var discoveredTools: [MCPTool] = []
    @State private var selectedTools: Set<String> = []
    @State private var isDiscovering = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if isDiscovering {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Discovering tools...")
                        .padding()
                } else if errorMessage != nil {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Discovery Failed")
                            .font(.headline)
                        Text(errorMessage ?? "Unknown error")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if discoveredTools.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Tools Found")
                            .font(.headline)
                        Text("Click 'Discover Tools' to fetch available tools from your MCP server")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(discoveredTools, id: \.name) { tool in
                            HStack {
                                Image(systemName: selectedTools.contains(tool.name) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedTools.contains(tool.name) ? .blue : .gray)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    // Show title if available, otherwise use name
                                    Text(tool.title ?? tool.name)
                                        .font(.headline)
                                    
                                    if let description = tool.description {
                                        Text(description)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedTools.contains(tool.name) {
                                    selectedTools.remove(tool.name)
                                } else {
                                    selectedTools.insert(tool.name)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: discoverTools) {
                        Label("Discover Tools", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(isDiscovering)
                    
                    Button(action: saveTools) {
                        Label("Save Selection", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedTools.isEmpty ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(selectedTools.isEmpty || isDiscovering)
                }
                .padding()
            }
            .navigationTitle("MCP Tools")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Load current selection
                selectedTools = Set(settings.selectedTools)
            }
        }
    }
    
    private func discoverTools() {
        isDiscovering = true
        errorMessage = nil
        
        Task {
            do {
                let tools = try await MCPClient.shared.fetchTools()
                await MainActor.run {
                    discoveredTools = tools
                    isDiscovering = false
                    
                    if tools.isEmpty {
                        errorMessage = "No tools discovered. Check your MCP server configuration."
                    }
                }
            } catch {
                await MainActor.run {
                    isDiscovering = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func saveTools() {
        settings.selectedTools = Array(selectedTools)
        dismiss()
    }
}

#Preview {
    ToolDiscoveryView()
}


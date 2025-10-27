//
//  ChatView.swift
//  HelloWorld
//
//  Created by Acacio Santana on 10/26/25.
//

import SwiftUI

struct ChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var thinkingMessage: String?
    @State private var currentToolCall: String?
    @State private var thinkingTokens: String?
    @State private var temporaryThinkingMessage: ChatMessage?
    @State private var mcpToolCallInfo: String?
    @State private var isRecordingVoice = false
    @ObservedObject private var voiceService = VoiceService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat messages area - takes remaining space
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                        
                        // Show temporary thinking message if present
                        if let tempMessage = temporaryThinkingMessage {
                            ChatBubble(message: tempMessage)
                                .id("thinking-temp")
                                .opacity(0.7)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: messages.count) {
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }
            
            // Current tool call indicator
            if let toolCall = currentToolCall {
                HStack {
                    Image(systemName: "wrench.fill")
                        .foregroundColor(.blue)
                    Text("Calling: \(toolCall)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
            
            // Input area - fixed at bottom
            HStack(spacing: 8) {
                TextField("Type a message...", text: $inputText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(24)
                    .disabled(isLoading)
                    .onSubmit(sendMessage)
                
                // Voice button (if enabled)
                if SettingsManager.shared.voiceEnabled {
                    Button(action: toggleVoiceRecording) {
                        Image(systemName: isRecordingVoice ? "mic.fill" : "mic.slash")
                            .font(.title2)
                            .foregroundColor(isRecordingVoice ? .red : .blue)
                            .padding(8)
                    }
                    .disabled(isLoading)
                }
                
                Button(action: sendMessage) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.regular)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    }
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .background(Color(.systemBackground))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 0)
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendMessage() {
        let userMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty else { return }
        
        let newMessage = ChatMessage(role: "user", content: userMessage)
        messages.append(newMessage)
        inputText = ""
        isLoading = true
        errorMessage = nil
        thinkingMessage = "Thinking..."
        currentToolCall = nil
        
        Task {
            do {
                let response = try await APIService.shared.sendMessage(
                    message: userMessage,
                    chatHistory: messages,
                    onThinking: { thinkingText in
                        Task { @MainActor in
                            thinkingMessage = thinkingText
                        }
                    },
                    onToolCall: { toolName in
                        Task { @MainActor in
                            currentToolCall = toolName
                        }
                    },
                    onThinkingTokens: { tokens in
                        // Set thinking tokens synchronously so they're available when we capture
                        thinkingTokens = tokens
                    },
                    onMCPToolInfo: { toolInfo in
                        // Capture MCP tool call information
                        mcpToolCallInfo = toolInfo
                    }
                )
                
                // Capture thinkingTokens from the current state before clearing
                let capturedThinking = thinkingTokens
                print("📝 Creating assistant message with thinking: \(capturedThinking ?? "nil")")
                
                // Combine thinking with MCP tool info if available and setting is enabled
                let settings = SettingsManager.shared
                var fullThinking = capturedThinking
                if settings.showMCPInReasoning {
                    if let toolInfo = mcpToolCallInfo, let thinking = capturedThinking {
                        fullThinking = "\(thinking)\n\n\(toolInfo)"
                    } else if let toolInfo = mcpToolCallInfo {
                        fullThinking = toolInfo
                    }
                }
                
                let assistantMessage = ChatMessage(role: "assistant", content: response, thinking: fullThinking)
                await MainActor.run {
                    // Add final answer (thinking message is already in chat history)
                    temporaryThinkingMessage = nil
                    messages.append(assistantMessage)
                    isLoading = false
                    thinkingMessage = nil
                    currentToolCall = nil
                    thinkingTokens = nil
                    mcpToolCallInfo = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error: \(error.localizedDescription)"
                    isLoading = false
                    thinkingMessage = nil
                    currentToolCall = nil
                    thinkingTokens = nil
                    temporaryThinkingMessage = nil
                }
            }
        }
    }
    
    private func toggleVoiceRecording() {
        if isRecordingVoice {
            stopVoiceRecording()
        } else {
            startVoiceRecording()
        }
    }
    
    private func startVoiceRecording() {
        Task {
            let hasPermission = await voiceService.requestPermissions()
            guard hasPermission else {
                await MainActor.run {
                    errorMessage = "Microphone permission denied. Please enable in Settings."
                }
                return
            }
            
            await MainActor.run {
                isRecordingVoice = true
                errorMessage = nil
            }
            
            do {
                try voiceService.startRecording()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to start recording: \(error.localizedDescription)"
                    isRecordingVoice = false
                }
            }
        }
    }
    
    private func stopVoiceRecording() {
        guard let audioURL = voiceService.stopRecording() else {
            isRecordingVoice = false
            return
        }
        
        isRecordingVoice = false
        isLoading = true
        thinkingMessage = "Transcribing..."
        
        Task {
            do {
                let transcribedText = try await voiceService.transcribe(audioURL: audioURL)
                
                await MainActor.run {
                    // Show transcribed text in input field
                    inputText = transcribedText
                    isLoading = false
                    thinkingMessage = nil
                }
                
                // Auto-send after a brief delay to show the text first
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                await MainActor.run {
                    sendMessage()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Transcription failed: \(error.localizedDescription)"
                    isLoading = false
                    thinkingMessage = nil
                }
            }
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    @State private var showThinking = false
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
            }
            
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.content)
                        .padding()
                        .background(message.role == "user" ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(message.role == "user" ? .white : .primary)
                        .cornerRadius(16)
                    
                    // Show thinking tokens if available
                    if let thinking = message.thinking, !thinking.isEmpty {
                        Button(action: { showThinking.toggle() }) {
                            HStack {
                                Image(systemName: showThinking ? "chevron.up" : "chevron.down")
                                Text(showThinking ? "Hide reasoning" : "Show reasoning")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                        
                        if showThinking {
                            Text(thinking)
                                .font(.caption)
                                .padding()
                                .background(Color.yellow.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                                .frame(maxWidth: 280)
                        }
                    }
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 280, alignment: message.role == "user" ? .trailing : .leading)
            
            if message.role == "assistant" {
                Spacer()
            }
        }
    }
}

#Preview {
    ChatView()
}


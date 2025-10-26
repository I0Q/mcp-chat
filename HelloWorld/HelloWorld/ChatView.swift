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
                        Task { @MainActor in
                            thinkingTokens = tokens
                            // Update temporary message with thinking tokens
                            temporaryThinkingMessage = ChatMessage(role: "assistant", content: "Thinking...\n\n\(tokens)")
                        }
                    }
                )
                let assistantMessage = ChatMessage(role: "assistant", content: response)
                await MainActor.run {
                    // Remove temporary thinking message and add final answer
                    temporaryThinkingMessage = nil
                    messages.append(assistantMessage)
                    isLoading = false
                    thinkingMessage = nil
                    currentToolCall = nil
                    thinkingTokens = nil
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
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
            }
            
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding()
                    .background(message.role == "user" ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.role == "user" ? .white : .primary)
                    .cornerRadius(16)
                
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


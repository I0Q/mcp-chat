//
//  APIService.swift
//  HelloWorld
//
//  Created by Acacio Santana on 10/26/25.
//

import Foundation

class APIService {
    static let shared = APIService()
    
    private init() {}
    
    func sendMessage(message: String, chatHistory: [ChatMessage]) async throws -> String {
        let settings = SettingsManager.shared
        let urlString = "\(settings.serverURL)/v1/chat/completions"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        // Convert chat history to API format
        let messages = chatHistory.map { msg in
            ["role": msg.role, "content": msg.content]
        }
        
        let requestBody: [String: Any] = [
            "model": settings.selectedModel,
            "messages": messages
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let responseData = try decoder.decode(ChatCompletionResponse.self, from: data)
        
        return responseData.choices.first?.message.content ?? ""
    }
    
    enum APIError: LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(Int)
        case decodingError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response from server"
            case .httpError(let code):
                return "HTTP Error: \(code)"
            case .decodingError:
                return "Failed to decode response"
            }
        }
    }
}

struct ChatCompletionResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}


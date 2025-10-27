//
//  ChatMessage.swift
//  HelloWorld
//
//  Created by Acacio Santana on 10/26/25.
//

import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: String
    let content: String
    let timestamp: Date
    let thinking: String?
    
    init(role: String, content: String, thinking: String? = nil, id: UUID = UUID()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.thinking = thinking
    }
}


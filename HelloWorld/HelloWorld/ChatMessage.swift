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
    
    init(role: String, content: String, id: UUID = UUID()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}


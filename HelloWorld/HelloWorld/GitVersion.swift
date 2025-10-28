//
//  GitVersion.swift
//  HelloWorld
//
//  Helper to get git branch name at runtime
//

import Foundation

struct GitVersion {
    static func getBranchName() -> String {
        // For now, return the current branch name
        // This should be updated when switching branches
        return "multi-mcp"
    }
}

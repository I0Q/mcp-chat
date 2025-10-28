//
//  GeneratedVersion.swift
//  HelloWorld
//
//  Reads git branch name from file written during build
//

import Foundation

struct GeneratedVersion {
    static var branchName: String {
        if let branchNameFilePath = Bundle.main.path(forResource: "branch_name", ofType: "txt") {
            do {
                let branchName = try String(contentsOfFile: branchNameFilePath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
                return branchName
            } catch {
                print("Error reading branch name: \(error)")
            }
        } else {
            print("Branch name file not found.")
        }
        
        // Fallback to hardcoded value
        return "multi-mcp"
    }
}

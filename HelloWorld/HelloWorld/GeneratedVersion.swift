//
//  GeneratedVersion.swift
//  HelloWorld
//
//  Reads git branch name and hash from file written during build
//

import Foundation

struct GeneratedVersion {
    static var branchName: String {
        return gitInfo.branch
    }
    
    static var gitHash: String {
        return gitInfo.hash
    }
    
    static var versionString: String {
        return "\(gitInfo.branch) (\(gitInfo.hash))"
    }
    
    private static var gitInfo: (branch: String, hash: String) {
        if let gitInfoFilePath = Bundle.main.path(forResource: "git_info", ofType: "txt") {
            do {
                let content = try String(contentsOfFile: gitInfoFilePath, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
                
                let branch = lines.count > 0 ? lines[0].trimmingCharacters(in: .whitespacesAndNewlines) : "unknown"
                let hash = lines.count > 1 ? lines[1].trimmingCharacters(in: .whitespacesAndNewlines) : "unknown"
                
                return (branch: branch, hash: hash)
            } catch {
                print("Error reading git info: \(error)")
            }
        } else {
            print("Git info file not found.")
        }
        
        // Fallback values
        return (branch: "multi-mcp", hash: "unknown")
    }
}

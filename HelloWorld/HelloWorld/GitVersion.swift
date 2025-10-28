//
//  GitVersion.swift
//  HelloWorld
//
//  Helper to get git branch name at runtime
//

import Foundation

struct GitVersion {
    static func getBranchName() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if process.terminationStatus == 0 && !output.isEmpty {
                return output
            }
        } catch {
            print("Error getting git branch: \(error)")
        }
        
        return "Unknown"
    }
}

//
//  VoiceService.swift
//  HelloWorld
//
//  Voice recording and transcription using Whisper server
//

import Foundation
import AVFoundation
import Combine

class VoiceService: NSObject, AVAudioRecorderDelegate, ObservableObject {
    static let shared = VoiceService()
    
    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    private var recordingTimer: Timer?
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    func requestPermissions() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
    
    func startRecording() throws {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        audioFileURL = documentsPath.appendingPathComponent("recording.wav")
        
        guard let url = audioFileURL else {
            throw VoiceError.fileError
        }
        
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.record()
        
        isRecording = true
        recordingDuration = 0
        
        // Start timer for recording duration
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingDuration += 0.1
        }
        
        print("🎤 Started recording")
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        
        print("🎤 Stopped recording, duration: \(String(format: "%.1f", recordingDuration))s")
        
        return audioFileURL
    }
    
    func transcribe(audioURL: URL, onPartialTranscript: ((String) -> Void)? = nil) async throws -> String {
        let settings = await SettingsManager.shared
        guard let baseURL = await URL(string: settings.voiceServiceURL) else {
            throw VoiceError.invalidURL
        }
        // Append /asr endpoint
        let serverURL = baseURL.appendingPathComponent("asr")
        
        // Read audio file data
        let audioData = try Data(contentsOf: audioURL)
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio_file\"; filename=\"recording.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add task parameter for transcription
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"task\"\r\n\r\n".data(using: .utf8)!)
        body.append("transcribe\r\n".data(using: .utf8)!)
        
        // Add response format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("📤 Sending audio to \(await settings.voiceServiceURL)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Transcription failed with status: \(httpResponse.statusCode)")
            if let errorData = String(data: data, encoding: .utf8) {
                print("Error response: \(errorData)")
            }
            throw VoiceError.httpError(httpResponse.statusCode)
        }
        
        // Try to parse as JSON first
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Try different possible response formats
            var text: String?
            
            if let transcribedText = json["text"] as? String {
                text = transcribedText
            } else if let segments = json["segments"] as? [[String: Any]] {
                // If response has segments, extract all text
                text = segments.compactMap { $0["text"] as? String }.joined(separator: " ")
            } else if let result = json["result"] as? String {
                text = result
            }
            
            if let finalText = text, !finalText.isEmpty {
                print("✅ Transcription: \(finalText)")
                return finalText
            }
        }
        
        // If not JSON or failed to parse JSON, try as plain text
        if let plainText = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !plainText.isEmpty {
            print("✅ Transcription (plain text): \(plainText)")
            return plainText
        }
        
        // Failed to decode
        print("❌ Failed to parse response. Raw data: \(String(data: data, encoding: .utf8) ?? "unknown")")
        throw VoiceError.decodingError
    }
    
    enum VoiceError: LocalizedError {
        case fileError
        case invalidURL
        case invalidResponse
        case httpError(Int)
        case decodingError
        
        var errorDescription: String? {
            switch self {
            case .fileError: return "Failed to create audio file"
            case .invalidURL: return "Invalid transcription server URL"
            case .invalidResponse: return "Invalid server response"
            case .httpError(let code): return "HTTP Error: \(code)"
            case .decodingError: return "Failed to decode transcription"
            }
        }
    }
}


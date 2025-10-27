//
//  VoiceRecordingOverlay.swift
//  HelloWorld
//
//  Full-screen overlay for voice recording with audio wave animation
//

import SwiftUI

struct VoiceRecordingOverlay: View {
    @Binding var isPresented: Bool
    @Binding var isRecording: Bool
    @State private var animationPhase: CGFloat = 0
    @State private var recordingDuration: TimeInterval = 0
    
    let onTapStop: () -> Void
    
    var body: some View {
        if isPresented {
            ZStack {
                // Full-screen semi-transparent background
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Allow tap outside to cancel
                        isPresented = false
                    }
                
                VStack(spacing: 30) {
                    // Title
                    Text("Recording...")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(.top, 80)
                    
                    // Audio wave circle
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .scaleEffect(isRecording ? 1.3 : 1.0)
                            .opacity(isRecording ? 0 : 1)
                            .animation(
                                Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: isRecording
                            )
                        
                        // Animated audio waves
                        HStack(spacing: 4) {
                            ForEach(0..<5) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white)
                                    .frame(width: 4, height: waveHeight(for: index))
                                    .animation(
                                        Animation.easeInOut(duration: 0.4)
                                            .repeatForever()
                                            .delay(Double(index) * 0.1),
                                        value: animationPhase
                                    )
                            }
                        }
                        .frame(width: 120, height: 50)
                    }
                    .padding()
                    
                    // Duration display
                    Text(formatDuration(recordingDuration))
                        .font(.title)
                        .foregroundColor(.white)
                    
                    // Stop button
                    Button(action: onTapStop) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "stop.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Instructions
                    Text("Tap circle to stop")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 60)
                }
            }
            .onAppear {
                startAnimation()
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
        }
    }
    
    private func waveHeight(for index: Int) -> CGFloat {
        if !isRecording { return 20 }
        let baseOffset = animationPhase + Double(index)
        let normalizedOffset = baseOffset.truncatingRemainder(dividingBy: 2 * .pi)
        return 20 + sin(normalizedOffset) * 15 + 5
    }
    
    private func startAnimation() {
        animationPhase = 0
        withAnimation(
            Animation.linear(duration: 2.0).repeatForever(autoreverses: false)
        ) {
            animationPhase = 2 * .pi
        }
    }
    
    @State private var timer: Timer?
    
    private func startTimer() {
        recordingDuration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration) % 60
        let minutes = Int(duration) / 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


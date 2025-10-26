import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Icon
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.blue)
                
                // Main text
                Text("Hello, World!")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.primary)
                
                // Subtitle
                Text("Welcome to iOS Development")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                // Info text
                Text("Built with SwiftUI")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}


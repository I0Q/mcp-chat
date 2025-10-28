# Release v1.0

## Features

### Core Functionality
- LLM chat interface with OpenAI-compatible API
- Multiple model support (openai/gpt-oss-20b, openai/gpt-oss-120b)
- Chat history management
- Real-time thinking token display
- Collapsible reasoning view with thinking tokens

### MCP (Model Context Protocol) Integration
- Generic MCP client via Server-Sent Events (SSE)
- Tool discovery interface
- Visual tool selection and caching
- Real-time tool execution during chat
- MCP tool call info in reasoning display (optional toggle)
- Full MCP protocol support (initialize, tools/list, tools/call)

### Voice Features
- Audio recording with AVAudioRecorder
- Full-screen recording overlay with animated audio waves
- Real-time duration display
- Tap-to-stop with automatic transcription
- Integration with Whisper ASR server
- Direct message sending after transcription

### Settings
- LLM server configuration
- Model selection
- Thinking mode and effort settings
- MCP server configuration (URL, auth, tools)
- Voice transcription service configuration
- Tool discovery and selection
- Debug logging toggle

## Technical Details

### Architecture
- SwiftUI-based iOS app
- ObservableObject pattern for state management
- UserDefaults for persistent settings
- URLSession for network requests
- SSE streaming for MCP and LLM responses

### Dependencies
- SwiftUI
- AVFoundation
- Combine
- Foundation

## Requirements
- iOS 16.0+
- Network access to LLM server
- Optional: MCP server for tool use
- Optional: Whisper server for voice transcription

## Installation
Clone the repository and open in Xcode:
```bash
git clone https://github.com/I0Q/mcp-chat.git
cd mcp-chat
open HelloWorld/HelloWorld.xcodeproj
```


#!/bin/bash

# Create a simple test audio file (1 second of silence at 16kHz)
# Using /dev/zero as a dummy audio file for testing the API structure
dd if=/dev/zero of=test_audio.wav bs=32000 count=1 2>/dev/null

echo "Testing Whisper API structure..."
curl -X POST http://192.168.1.232:8005/asr \
  -F "audio_file=@test_audio.wav" \
  -F "model=whisper-1" 2>&1 || echo "Connection failed"

echo ""
echo "Testing alternate endpoint..."
curl -X POST http://192.168.1.232:8005/v1/audio/transcriptions \
  -F "file=@test_audio.wav" \
  -F "model=whisper-1" 2>&1 || echo "Connection failed"

# Cleanup
rm -f test_audio.wav

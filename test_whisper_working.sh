# Commands for testing on the server (192.168.1.232)

# 1. Download a sample audio file for testing
wget -q https://github.com/hf-internal-testing/dgAudio-mini/raw/main/sample1.flac -O test_audio.flac || \
wget -q http://www.voiptroubleshooter.com/open_speech/american/OSR_us_000_0010_8k.wav -O test_audio.wav || \
echo "Download failed, creating dummy audio..."

# 2. If download failed, create minimal valid WAV file
if [ ! -f test_audio.wav ]; then
    # Create a minimal valid WAV file (1 second of silence)
    printf "RIFF" > test_audio.wav
    printf "\x24\x08\x00\x00" >> test_audio.wav
    printf "WAVE" >> test_audio.wav
    printf "fmt \x10\x00\x00\x00\x01\x00\x01\x00\x44\xac\x00\x00\x88\x58\x01\x00\x02\x00\x10\x00" >> test_audio.wav
    printf "data\x00\x08\x00\x00" >> test_audio.wav
fi

echo ""
echo "Testing /asr endpoint:"
curl -X POST http://localhost:8005/asr \
  -F "audio_file=@test_audio.flac" \
  -F "task=transcribe" \
  -F "response_format=json" 2>&1 || \
curl -X POST http://localhost:8005/asr \
  -F "audio_file=@test_audio.wav" \
  -F "task=transcribe" \
  -F "response_format=json" 2>&1

echo ""
echo ""
echo "Testing /v1/audio/transcriptions (OpenAI compatible):"
curl -X POST http://localhost:8005/v1/audio/transcriptions \
  -F "file=@test_audio.wav" \
  -F "model=whisper-1" \
  -F "response_format=json" 2>&1

# Cleanup
rm -f test_audio.*

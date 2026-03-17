# Sparkle - Voice-to-Text macOS Application

A macOS application for audio recording with STT (Speech-to-Text) transcription and LLM-powered text polishing. Features hotkey-based recording controls and automatic clipboard integration.

## Requirements

- macOS 15.0+
- Xcode 15+

## Project Structure

```
Sparkle/
├── Sparkle.xcodeproj/
├── Sparkle/
│   ├── SparkleApp.swift                # Main app entry with scenes
│   ├── Info.plist                      # App configuration
│   ├── Sparkle.entitlements            # App permissions
│   ├── Models/
│   │   ├── Recording.swift             # SwiftData model
│   │   ├── STTProvider.swift           # STT provider enum
│   │   └── AppSettings.swift           # User settings
│   ├── Views/
│   │   ├── MainView.swift              # Main window
│   │   ├── HistoryView.swift           # Recording history sidebar
│   │   ├── TranscriptEditorView.swift  # Transcript viewer/editor
│   │   ├── SettingsView.swift          # Settings configuration
│   │   ├── MenuBarView.swift           # Menu bar content
│   │   └── RecordingWidget/
│   │       ├── RecordingWidgetView.swift
│   │       ├── WaveformView.swift
│   │       └── RecordingWidgetWindow.swift
│   ├── Services/
│   │   ├── AudioRecorder.swift         # AVFoundation recording
│   │   ├── HotkeyManager.swift         # Global fn key monitoring
│   │   ├── LLMService.swift            # LLM text polishing
│   │   └── STT/
│   │       ├── STTServiceProtocol.swift
│   │       ├── OpenAIWhisperService.swift
│   │       ├── LocalWhisperService.swift
│   │       ├── DeepgramService.swift
│   │       ├── AssemblyAIService.swift
│   │       └── CustomSTTService.swift
│   ├── Managers/
│   │   ├── RecordingManager.swift      # Recording flow orchestration
│   │   └── ClipboardManager.swift      # Auto-paste functionality
│   └── Resources/
│       └── Assets.xcassets
```

## Features

### Audio Recording
- AVAudioRecorder-based recording with real-time waveform visualization
- M4A audio format with high quality encoding

### Multiple STT Providers
- **OpenAI Whisper** - OpenAI's Whisper API
- **Deepgram** - Deepgram speech recognition API
- **AssemblyAI** - AssemblyAI transcription service
- **Custom API** - Any OpenAI-compatible endpoint
- **Local Whisper** - Placeholder for WhisperKit integration

### LLM Text Polishing
- OpenAI-compatible API integration
- Customizable system prompt for text formatting
- Automatic grammar and punctuation fixes
- Removes filler words and repetitions

### Hotkey Controls
| Action | Trigger | Result |
|--------|---------|--------|
| Hold Recording | Hold `fn` | Record while held, stop on release |
| Hands-free Start | Double-press `fn` | Start continuous recording |
| Hands-free Start | `fn + Space` | Start continuous recording |
| Hands-free Stop | Press `fn` again | Complete recording |

### Menu Bar Integration
- Quick access via MenuBarExtra
- Recording status indicator with pulse animation
- Start/stop recording from menu

### Recording History
- SwiftData persistence
- Search through recordings
- View original transcript and polished text
- Re-polish recordings with updated prompts

### Auto-Paste
- Copies result to clipboard
- Optional automatic paste at cursor position (simulates Cmd+V)

### Floating Widget
- Shows recording status with live waveform
- Cancel or complete recording with buttons
- Processing progress indicator

## Build & Run

```bash
# Open project in Xcode
open Sparkle.xcodeproj

# Build from command line
xcodebuild -project Sparkle.xcodeproj -scheme Sparkle -configuration Debug build

# Run the app
open ./build/Debug/Sparkle.app
```

## Configuration

1. Launch Sparkle
2. Open Settings (Cmd+,)
3. Configure API settings:
   - **STT Provider**: Select your preferred speech-to-text service
   - **STT API URL**: API endpoint (pre-filled for known providers)
   - **STT API Key**: Your API key for the selected provider
   - **LLM API URL**: OpenAI-compatible chat completions endpoint
   - **LLM API Key**: Your LLM API key
   - **LLM Model**: Model to use (default: gpt-4o-mini)
4. Customize the transcription prompt if needed
5. Enable/disable hotkeys and auto-paste

## Usage

1. **Start Recording**:
   - Hold the `fn` key to record while held
   - Double-tap `fn` or press `fn + Space` for hands-free recording
   - Click "Start Recording" in the menu bar

2. **Stop Recording**:
   - Release `fn` key (hold mode)
   - Press `fn` again (hands-free mode)
   - Click the checkmark on the floating widget

3. **Cancel Recording**:
   - Click the X button on the floating widget

4. **View Results**:
   - Text is automatically copied to clipboard
   - If auto-paste is enabled, text is pasted at cursor
   - View history in the main window

## Permissions Required

- **Microphone Access**: For audio recording
- **Accessibility** (optional): For global hotkey monitoring
- **Network Access**: For API calls to STT/LLM services

## Tech Stack

- **Framework**: SwiftUI
- **Audio**: AVFoundation
- **Storage**: SwiftData
- **Networking**: URLSession
- **UI**: Menu Bar Extra, Floating Windows

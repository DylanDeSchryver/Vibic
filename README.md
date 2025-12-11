# Vibic - iOS Music Player

A lightweight iOS music player app built with SwiftUI and AVFoundation.

## Features

### Core Modules

1. **Download Subsystem** (`AudioFileManager`)
   - Import audio files from the iOS file system
   - Supports MP3, M4A, WAV, AAC, FLAC, AIFF formats
   - Automatic metadata extraction (title, artist, duration)
   - File sharing enabled for easy file transfer via iTunes/Finder

2. **Local File Library** (`CoreDataManager` + `LibraryController`)
   - Core Data persistence for track metadata
   - Fields: track name, file path, duration, artist, file size, user-assigned tags
   - Search and filter capabilities
   - Library validation to remove orphaned entries

3. **Playlist Manager** (`PlaylistManager`)
   - Create, rename, and delete playlists
   - Add, remove, and reorder tracks within playlists
   - Ordered lists with Core Data persistence
   - Duplicate and merge playlist operations

4. **Audio Playback Engine** (`AudioPlaybackEngine`)
   - Built on AVAudioPlayer for reliable playback
   - Play/pause/seek controls
   - Queue management with shuffle and repeat modes
   - Background audio playback support
   - Now Playing info integration (Control Center/Lock Screen)
   - Remote command handling (headphone controls)

### User Interface

- **Library View**: Browse all imported tracks with search, tagging, and playlist assignment
- **Playlist View**: Manage playlists with drag-to-reorder and shuffle play
- **File Browser**: Import audio files using the system document picker
- **Player View**: Full-screen player with progress scrubbing, volume control, and queue controls
- **Mini Player**: Persistent bottom player bar for quick access

## Architecture

```
Vibic/
├── VibicApp.swift              # App entry point, audio session config
├── ContentView.swift           # Main tab view with mini player
├── Core/
│   ├── CoreDataManager.swift   # Core Data stack and operations
│   ├── AudioFileManager.swift  # File import and metadata extraction
│   ├── LibraryController.swift # Central coordinator (ObservableObject)
│   ├── PlaylistManager.swift   # Playlist operations
│   └── AudioPlaybackEngine.swift # AVFoundation playback engine
├── Models/
│   ├── VibicModel.xcdatamodeld # Core Data model (Track, Playlist, PlaylistItem)
│   ├── Track+Extensions.swift  # Track convenience properties
│   └── Playlist+Extensions.swift # Playlist convenience properties
├── Views/
│   ├── LibraryView.swift       # Track library with search/tags
│   ├── FileBrowserView.swift   # File import interface
│   ├── PlaylistView.swift      # Playlist list and detail views
│   ├── PlayerView.swift        # Full-screen player
│   ├── MiniPlayerView.swift    # Bottom mini player bar
│   ├── TrackRowView.swift      # Reusable track list item
│   └── PlaylistEditorView.swift # Add tracks to playlist
└── Assets.xcassets/            # App icons and colors
```

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Setup

1. Open `Vibic.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run on a device or simulator

## Usage

1. **Import Music**: Go to the Files tab and tap "Browse Files" to import audio files from your device
2. **Browse Library**: View all imported tracks in the Library tab
3. **Create Playlists**: Go to Playlists tab and tap + to create a new playlist
4. **Add to Playlist**: Swipe right on a track or use the context menu to add it to a playlist
5. **Playback**: Tap any track to start playing; use the mini player or tap it to open full player

## File Sharing

Vibic supports file sharing via iTunes/Finder. Connect your device and drag audio files directly into the Vibic documents folder.

## Background Playback

The app is configured for background audio playback. Music will continue playing when the app is in the background, and controls are available from Control Center and Lock Screen.

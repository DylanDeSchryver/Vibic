import SwiftUI

struct LyricsView: View {
    @EnvironmentObject var playbackEngine: AudioPlaybackEngine
    @StateObject private var lyricsService = LyricsService.shared
    @State private var currentLineIndex: Int? = nil
    @Namespace private var scrollNamespace
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.4), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if playbackEngine.currentTrack == nil {
                    noTrackView
                } else if lyricsService.isLoading {
                    loadingView
                } else if lyricsService.hasSyncedLyrics {
                    syncedLyricsView
                } else if let lyrics = lyricsService.currentLyrics {
                    plainLyricsView(lyrics: lyrics)
                } else if lyricsService.error != nil {
                    noLyricsView
                } else {
                    noLyricsView
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(playbackEngine.currentTrack?.displayTitle ?? "")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text(playbackEngine.currentTrack?.displayArtist ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .onChange(of: playbackEngine.currentTrack?.id) { _, _ in
            fetchLyricsForCurrentTrack()
            currentLineIndex = nil
        }
        .onChange(of: playbackEngine.currentTime) { _, newTime in
            updateCurrentLine(time: newTime)
        }
        .onAppear {
            fetchLyricsForCurrentTrack()
        }
    }
    
    // MARK: - Synced Lyrics View (Auto-scrolling)
    
    private var syncedLyricsView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Synced indicator
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.caption)
                        Text("SYNCED LYRICS")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
                    
                    // Spacer at top for better scrolling
                    Color.clear.frame(height: 100)
                    
                    // Lyrics lines
                    ForEach(Array(lyricsService.syncedLyrics.enumerated()), id: \.element.id) { index, line in
                        SyncedLyricLineView(
                            line: line,
                            isCurrentLine: index == currentLineIndex,
                            isPastLine: currentLineIndex != nil && index < currentLineIndex!
                        )
                        .id(index)
                        .onTapGesture {
                            // Tap to seek to this line
                            playbackEngine.seek(to: line.time)
                        }
                    }
                    
                    // Spacer at bottom
                    Color.clear.frame(height: 300)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .scrollIndicators(.hidden)
            .onChange(of: currentLineIndex) { _, newIndex in
                if let index = newIndex {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - Plain Lyrics View (No timing)
    
    private func plainLyricsView(lyrics: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("LYRICS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)
                
                Text(lyrics)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineSpacing(8)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
    }
    
    // MARK: - Empty States
    
    private var noTrackView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Track Playing")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Play a song to see lyrics")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Finding lyrics...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var noLyricsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.quote")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Lyrics Not Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("We couldn't find lyrics for this song")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button {
                fetchLyricsForCurrentTrack()
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Helpers
    
    private func fetchLyricsForCurrentTrack() {
        guard let track = playbackEngine.currentTrack else {
            lyricsService.clearLyrics()
            return
        }
        
        Task {
            await lyricsService.fetchLyrics(
                for: track.displayTitle,
                artist: track.artist
            )
        }
    }
    
    private func updateCurrentLine(time: Double) {
        guard lyricsService.hasSyncedLyrics else { return }
        let newIndex = lyricsService.getCurrentLineIndex(at: time)
        if newIndex != currentLineIndex {
            currentLineIndex = newIndex
        }
    }
}

// MARK: - Synced Lyric Line View

struct SyncedLyricLineView: View {
    let line: LyricLine
    let isCurrentLine: Bool
    let isPastLine: Bool
    
    var body: some View {
        Text(line.text)
            .font(.title2)
            .fontWeight(isCurrentLine ? .bold : .semibold)
            .foregroundStyle(textColor)
            .lineSpacing(4)
            .padding(.vertical, 8)
            .scaleEffect(isCurrentLine ? 1.05 : 1.0, anchor: .leading)
            .animation(.easeInOut(duration: 0.2), value: isCurrentLine)
    }
    
    private var textColor: Color {
        if isCurrentLine {
            return .primary
        } else if isPastLine {
            return .secondary.opacity(0.5)
        } else {
            return .secondary.opacity(0.7)
        }
    }
}

#Preview {
    LyricsView()
        .environmentObject(AudioPlaybackEngine.shared)
}

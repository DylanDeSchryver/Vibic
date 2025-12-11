import SwiftUI

struct LyricsView: View {
    @EnvironmentObject var playbackEngine: AudioPlaybackEngine
    @StateObject private var lyricsService = LyricsService.shared
    
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
                } else if let lyrics = lyricsService.currentLyrics {
                    lyricsContentView(lyrics: lyrics)
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
        }
        .onAppear {
            fetchLyricsForCurrentTrack()
        }
    }
    
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
    
    private func lyricsContentView(lyrics: String) -> some View {
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
}

#Preview {
    LyricsView()
        .environmentObject(AudioPlaybackEngine.shared)
}

import SwiftUI

struct PlayerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var playbackEngine: AudioPlaybackEngine
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var showQueue = false
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    Spacer()
                    
                    artworkView(size: geometry.size.width - 80)
                    
                    Spacer()
                        .frame(height: 40)
                    
                    trackInfoView
                    
                    Spacer()
                        .frame(height: 32)
                    
                    progressView
                    
                    Spacer()
                        .frame(height: 24)
                    
                    controlsView
                    
                    Spacer()
                        .frame(height: 24)
                    
                    secondaryControlsView
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.3), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showQueue = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            // Share functionality
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        if let track = playbackEngine.currentTrack {
                            Button {
                                // Add to playlist
                            } label: {
                                Label("Add to Playlist", systemImage: "text.badge.plus")
                            }
                            
                            Divider()
                            
                            Text(track.displayFileSize)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showQueue) {
                QueueView()
                    .environmentObject(playbackEngine)
            }
        }
    }
    
    @ViewBuilder
    private func artworkView(size: CGFloat) -> some View {
        ZStack {
            if let artwork = playbackEngine.currentTrack?.artworkImage {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.6), Color.accentColor.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.3))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(playbackEngine.isPlaying ? 1.0 : 0.95)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: playbackEngine.isPlaying)
    }
    
    private var trackInfoView: some View {
        VStack(spacing: 8) {
            Text(playbackEngine.currentTrack?.displayTitle ?? "Not Playing")
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
            
            Text(playbackEngine.currentTrack?.displayArtist ?? "")
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
    
    private var progressView: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { isDragging ? dragValue : playbackEngine.currentTime },
                    set: { newValue in
                        dragValue = newValue
                        isDragging = true
                    }
                ),
                in: 0...max(playbackEngine.duration, 0.01),
                onEditingChanged: { editing in
                    if !editing {
                        playbackEngine.seek(to: dragValue)
                        isDragging = false
                    }
                }
            )
            .tint(.accent)
            
            HStack {
                Text(playbackEngine.formatTime(isDragging ? dragValue : playbackEngine.currentTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                
                Spacer()
                
                Text("-" + playbackEngine.formatTime(playbackEngine.duration - (isDragging ? dragValue : playbackEngine.currentTime)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
    
    private var controlsView: some View {
        HStack(spacing: 48) {
            Button {
                playbackEngine.playPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
            }
            .foregroundStyle(.primary)
            
            Button {
                playbackEngine.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 72, height: 72)
                    
                    Image(systemName: playbackEngine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .offset(x: playbackEngine.isPlaying ? 0 : 2)
                }
            }
            
            Button {
                playbackEngine.playNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
            }
            .foregroundStyle(.primary)
        }
    }
    
    private var secondaryControlsView: some View {
        HStack(spacing: 48) {
            Button {
                playbackEngine.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundStyle(playbackEngine.shuffleEnabled ? .accent : .secondary)
            }
            
            VolumeSlider()
                .frame(width: 120)
            
            Button {
                playbackEngine.cycleRepeatMode()
            } label: {
                Image(systemName: repeatIcon)
                    .font(.title3)
                    .foregroundStyle(playbackEngine.repeatMode != .none ? .accent : .secondary)
            }
        }
    }
    
    private var repeatIcon: String {
        switch playbackEngine.repeatMode {
        case .none:
            return "repeat"
        case .all:
            return "repeat"
        case .one:
            return "repeat.1"
        }
    }
}

struct VolumeSlider: View {
    @EnvironmentObject var playbackEngine: AudioPlaybackEngine
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Slider(value: Binding(
                get: { Double(playbackEngine.volume) },
                set: { playbackEngine.setVolume(Float($0)) }
            ), in: 0...1)
            .tint(.secondary)
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PlayerView()
        .environmentObject(AudioPlaybackEngine.shared)
}

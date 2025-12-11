import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var playbackEngine: AudioPlaybackEngine
    @Binding var showingPlayer: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress, height: 2)
            }
            .frame(height: 2)
            
            HStack(spacing: 12) {
                artworkView
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(playbackEngine.currentTrack?.displayTitle ?? "Not Playing")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(playbackEngine.currentTrack?.displayArtist ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button {
                        playbackEngine.togglePlayPause()
                    } label: {
                        Image(systemName: playbackEngine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                    .foregroundStyle(.primary)
                    
                    Button {
                        playbackEngine.playNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                    }
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
        .contentShape(Rectangle())
        .onTapGesture {
            showingPlayer = true
        }
    }
    
    private var artworkView: some View {
        ZStack {
            if let artwork = playbackEngine.currentTrack?.artworkImage {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.3))
                Image(systemName: "music.note")
                    .font(.body)
                    .foregroundStyle(.accent)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private var progress: CGFloat {
        guard playbackEngine.duration > 0 else { return 0 }
        return playbackEngine.currentTime / playbackEngine.duration
    }
}

#Preview {
    MiniPlayerView(showingPlayer: .constant(false))
        .environmentObject(AudioPlaybackEngine.shared)
}

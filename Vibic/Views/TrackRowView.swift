import SwiftUI

struct TrackRowView: View {
    @EnvironmentObject var playbackEngine: AudioPlaybackEngine
    let track: Track
    
    var isCurrentTrack: Bool {
        playbackEngine.currentTrack?.id == track.id
    }
    
    var body: some View {
        HStack(spacing: 12) {
            artworkView
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(track.displayTitle)
                        .font(.body)
                        .fontWeight(isCurrentTrack ? .semibold : .regular)
                        .foregroundStyle(isCurrentTrack ? .accent : .primary)
                        .lineLimit(1)
                    
                    if isCurrentTrack && playbackEngine.isPlaying {
                        NowPlayingIndicator()
                    }
                }
                
                HStack(spacing: 4) {
                    Text(track.displayArtist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    if !track.tagsArray.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(track.tagsArray.prefix(2).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            Text(track.displayDuration)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    
    private var artworkView: some View {
        ZStack {
            if let artwork = track.artworkImage {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isCurrentTrack ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.15))
                
                Image(systemName: "music.note")
                    .font(.caption)
                    .foregroundStyle(isCurrentTrack ? .accent : .secondary)
            }
            
            if isCurrentTrack && playbackEngine.isPlaying {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.black.opacity(0.4))
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct NowPlayingIndicator: View {
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 2, height: animate ? 10 : 4)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever()
                        .delay(Double(index) * 0.15),
                        value: animate
                    )
            }
        }
        .frame(width: 12, height: 12)
        .onAppear {
            animate = true
        }
    }
}

#Preview {
    List {
        TrackRowView(track: Track())
        TrackRowView(track: Track())
    }
    .environmentObject(AudioPlaybackEngine.shared)
}

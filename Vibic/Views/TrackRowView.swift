import SwiftUI

struct TrackRowView: View {
    let track: Track
    var isCurrentTrack: Bool = false
    var isPlaying: Bool = false
    
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
                    
                    if isCurrentTrack && isPlaying {
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
            LazyArtworkView(
                trackId: track.id,
                artworkData: track.artworkData,
                size: 44,
                cornerRadius: 6
            )
            
            if isCurrentTrack && isPlaying {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.black.opacity(0.4))
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 44, height: 44)
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
        TrackRowView(track: Track(), isCurrentTrack: true, isPlaying: true)
    }
}

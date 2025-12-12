import SwiftUI

struct QueueView: View {
    @EnvironmentObject var playbackEngine: AudioPlaybackEngine
    @Environment(\.dismiss) var dismiss
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        NavigationView {
            List {
                // Now Playing Section
                if let currentTrack = playbackEngine.currentTrack {
                    Section {
                        NowPlayingRow(track: currentTrack, isPlaying: playbackEngine.isPlaying)
                    } header: {
                        Text("Now Playing")
                    }
                }
                
                // Up Next Section
                if !playbackEngine.upcomingTracks.isEmpty {
                    Section {
                        ForEach(Array(playbackEngine.upcomingTracks.enumerated()), id: \.element.id) { index, track in
                            QueueTrackRow(
                                track: track,
                                queueIndex: playbackEngine.currentIndex + 1 + index,
                                onPlayNext: {
                                    withAnimation {
                                        playbackEngine.moveToPlayNext(from: playbackEngine.currentIndex + 1 + index)
                                    }
                                },
                                onPlay: {
                                    playbackEngine.playTrack(track, in: playbackEngine.queue)
                                }
                            )
                        }
                        .onMove { source, destination in
                            moveItems(from: source, to: destination)
                        }
                        .onDelete { indexSet in
                            deleteItems(at: indexSet)
                        }
                    } header: {
                        HStack {
                            Text("Up Next")
                            Spacer()
                            Text("\(playbackEngine.upcomingTracks.count) tracks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Empty State
                if playbackEngine.queue.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "Queue Empty",
                            systemImage: "music.note.list",
                            description: Text("Play some music to see your queue")
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                
                if !playbackEngine.upcomingTracks.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                clearUpcoming()
                            } label: {
                                Label("Clear Up Next", systemImage: "trash")
                            }
                            
                            if playbackEngine.shuffleEnabled {
                                Button {
                                    reshuffleQueue()
                                } label: {
                                    Label("Reshuffle", systemImage: "shuffle")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
        }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        // Convert relative indices to actual queue indices
        guard let sourceIndex = source.first else { return }
        let actualSourceIndex = playbackEngine.currentIndex + 1 + sourceIndex
        let actualDestination = playbackEngine.currentIndex + 1 + destination
        
        // Adjust destination if moving down
        let adjustedDestination = sourceIndex < destination ? actualDestination - 1 : actualDestination
        
        withAnimation {
            playbackEngine.moveTrack(from: actualSourceIndex, to: adjustedDestination)
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        // Convert relative indices to actual queue indices and delete in reverse order
        let indicesToDelete = offsets.map { playbackEngine.currentIndex + 1 + $0 }.sorted(by: >)
        
        withAnimation {
            for index in indicesToDelete {
                playbackEngine.removeFromQueue(at: index)
            }
        }
    }
    
    private func clearUpcoming() {
        withAnimation {
            while playbackEngine.queue.count > playbackEngine.currentIndex + 1 {
                playbackEngine.removeFromQueue(at: playbackEngine.queue.count - 1)
            }
        }
    }
    
    private func reshuffleQueue() {
        // Re-shuffle upcoming tracks
        let upcoming = Array(playbackEngine.queue[(playbackEngine.currentIndex + 1)...])
        let shuffled = upcoming.shuffled()
        
        // Remove and re-add in shuffled order
        while playbackEngine.queue.count > playbackEngine.currentIndex + 1 {
            playbackEngine.queue.removeLast()
        }
        playbackEngine.queue.append(contentsOf: shuffled)
    }
}

struct NowPlayingRow: View {
    let track: Track
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork - using lazy loading
            LazyArtworkView(
                trackId: track.id,
                artworkData: track.artworkData,
                size: 50,
                cornerRadius: 8
            )
            
            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title ?? "Unknown")
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let artist = track.artist {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Playing indicator
            if isPlaying {
                Image(systemName: "waveform")
                    .font(.title3)
                    .foregroundStyle(.tint)
            } else {
                Image(systemName: "pause.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 4)
    }
}

struct QueueTrackRow: View {
    let track: Track
    let queueIndex: Int
    let onPlayNext: () -> Void
    let onPlay: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork - using lazy loading
            LazyArtworkView(
                trackId: track.id,
                artworkData: track.artworkData,
                size: 44,
                cornerRadius: 6
            )
            
            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title ?? "Unknown")
                    .font(.body)
                    .lineLimit(1)
                
                if let artist = track.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Play Next button
            Button {
                onPlayNext()
            } label: {
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    .font(.body)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onPlay()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    QueueView()
        .environmentObject(AudioPlaybackEngine.shared)
}

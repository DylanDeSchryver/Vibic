import SwiftUI

struct PlaylistEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var libraryController: LibraryController
    @ObservedObject var playlist: Playlist
    @State private var searchText = ""
    @State private var selectedTracks: Set<UUID> = []
    
    var availableTracks: [Track] {
        let playlistTrackIDs = Set(playlist.tracks.compactMap { $0.id })
        let available = libraryController.tracks.filter { track in
            guard let trackID = track.id else { return false }
            return !playlistTrackIDs.contains(trackID)
        }
        
        if searchText.isEmpty {
            return available
        }
        
        let query = searchText.lowercased()
        return available.filter { track in
            (track.title?.lowercased().contains(query) ?? false) ||
            (track.artist?.lowercased().contains(query) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !selectedTracks.isEmpty {
                    selectionBar
                }
                
                if availableTracks.isEmpty {
                    emptyStateView
                } else {
                    trackList
                }
            }
            .navigationTitle("Add Tracks")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search library")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        addSelectedTracks()
                        dismiss()
                    }
                    .disabled(selectedTracks.isEmpty)
                }
            }
        }
    }
    
    private var selectionBar: some View {
        HStack {
            Text("\(selectedTracks.count) selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button("Select All") {
                for track in availableTracks {
                    if let id = track.id {
                        selectedTracks.insert(id)
                    }
                }
            }
            .font(.subheadline)
            
            Button("Clear") {
                selectedTracks.removeAll()
            }
            .font(.subheadline)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Tracks Available", systemImage: "music.note")
        } description: {
            if searchText.isEmpty {
                Text("All tracks are already in this playlist, or your library is empty.")
            } else {
                Text("No tracks match your search.")
            }
        }
    }
    
    private var trackList: some View {
        List(availableTracks, id: \.id, selection: $selectedTracks) { track in
            HStack(spacing: 12) {
                let isSelected = track.id.map { selectedTracks.contains($0) } ?? false
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .accent : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.displayTitle)
                        .font(.body)
                        .lineLimit(1)
                    
                    Text(track.displayArtist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(track.displayDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                toggleSelection(track)
            }
        }
        .listStyle(.plain)
    }
    
    private func toggleSelection(_ track: Track) {
        guard let trackID = track.id else { return }
        if selectedTracks.contains(trackID) {
            selectedTracks.remove(trackID)
        } else {
            selectedTracks.insert(trackID)
        }
    }
    
    private func addSelectedTracks() {
        for trackID in selectedTracks {
            if let track = libraryController.getTrack(by: trackID) {
                libraryController.addTrackToPlaylist(track, playlist: playlist)
            }
        }
    }
}

#Preview {
    PlaylistEditorView(playlist: Playlist())
        .environmentObject(LibraryController.shared)
}

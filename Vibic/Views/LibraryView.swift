import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var libraryController: LibraryController
    @EnvironmentObject var playbackEngine: AudioPlaybackEngine
    @State private var searchText = ""
    @State private var showingTagEditor = false
    @State private var selectedTrack: Track?
    @State private var showingAddToPlaylist = false
    @State private var isSelectMode = false
    @State private var selectedTracks: Set<UUID> = []
    @State private var showingAddMultipleToPlaylist = false
    @State private var showingDeleteConfirmation = false
    
    var filteredTracks: [Track] {
        libraryController.searchTracks(query: searchText)
            .sorted { ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "") == .orderedAscending }
    }
    
    var selectedTracksList: [Track] {
        filteredTracks.filter { track in
            guard let id = track.id else { return false }
            return selectedTracks.contains(id)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if libraryController.tracks.isEmpty {
                    emptyStateView
                } else {
                    trackListView
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search tracks")
            .refreshable {
                libraryController.loadLibrary()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isSelectMode {
                        Button("Cancel") {
                            isSelectMode = false
                            selectedTracks.removeAll()
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelectMode {
                        HStack(spacing: 16) {
                            Button {
                                showingDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .disabled(selectedTracks.isEmpty)
                            
                            Button("Add to Playlist") {
                                showingAddMultipleToPlaylist = true
                            }
                            .disabled(selectedTracks.isEmpty)
                        }
                    } else {
                        Menu {
                            Button {
                                isSelectMode = true
                            } label: {
                                Label("Select", systemImage: "checkmark.circle")
                            }
                            
                            Button {
                                libraryController.validateLibrary()
                            } label: {
                                Label("Validate Library", systemImage: "arrow.triangle.2.circlepath")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingTagEditor) {
                if let track = selectedTrack {
                    TagEditorView(track: track)
                }
            }
            .sheet(isPresented: $showingAddToPlaylist) {
                if let track = selectedTrack {
                    AddToPlaylistView(track: track)
                }
            }
            .sheet(isPresented: $showingAddMultipleToPlaylist) {
                AddMultipleToPlaylistView(tracks: selectedTracksList) {
                    isSelectMode = false
                    selectedTracks.removeAll()
                }
            }
            .alert("Delete \(selectedTracks.count) Tracks?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteSelectedTracks()
                }
            } message: {
                Text("This will permanently delete the selected tracks from your library and device.")
            }
        }
    }
    
    private func deleteSelectedTracks() {
        for track in selectedTracksList {
            libraryController.deleteTrack(track)
        }
        isSelectMode = false
        selectedTracks.removeAll()
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Tracks", systemImage: "music.note")
        } description: {
            Text("Import audio files from the Files tab to start building your library.")
        }
    }
    
    private var trackListView: some View {
        List {
            if isSelectMode {
                selectAllRow
            }
            
            ForEach(filteredTracks, id: \.id) { track in
                HStack(spacing: 12) {
                    if isSelectMode {
                        Image(systemName: isTrackSelected(track) ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(isTrackSelected(track) ? .accent : .secondary)
                    }
                    
                    TrackRowView(track: track)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if isSelectMode {
                        toggleTrackSelection(track)
                    } else {
                        playbackEngine.playTrack(track, in: filteredTracks)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if !isSelectMode {
                        Button(role: .destructive) {
                            libraryController.deleteTrack(track)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            selectedTrack = track
                            showingAddToPlaylist = true
                        } label: {
                            Label("Add to Playlist", systemImage: "plus")
                        }
                        .tint(.blue)
                    }
                }
                .swipeActions(edge: .leading) {
                    if !isSelectMode {
                        Button {
                            selectedTrack = track
                            showingTagEditor = true
                        } label: {
                            Label("Tags", systemImage: "tag")
                        }
                        .tint(.orange)
                    }
                }
                .contextMenu {
                    if !isSelectMode {
                        Button {
                            playbackEngine.playTrack(track, in: filteredTracks)
                        } label: {
                            Label("Play", systemImage: "play.fill")
                        }
                        
                        Button {
                            playbackEngine.addToQueue(track)
                        } label: {
                            Label("Add to Queue", systemImage: "text.badge.plus")
                        }
                        
                        Button {
                            selectedTrack = track
                            showingAddToPlaylist = true
                        } label: {
                            Label("Add to Playlist", systemImage: "music.note.list")
                        }
                        
                        Button {
                            selectedTrack = track
                            showingTagEditor = true
                        } label: {
                            Label("Edit Tags", systemImage: "tag")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            libraryController.deleteTrack(track)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    private var selectAllRow: some View {
        HStack {
            Text(selectedTracks.count == filteredTracks.count ? "Deselect All" : "Select All")
                .foregroundStyle(.accent)
            Spacer()
            Text("\(selectedTracks.count) selected")
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedTracks.count == filteredTracks.count {
                selectedTracks.removeAll()
            } else {
                selectedTracks = Set(filteredTracks.compactMap { $0.id })
            }
        }
    }
    
    private func isTrackSelected(_ track: Track) -> Bool {
        guard let id = track.id else { return false }
        return selectedTracks.contains(id)
    }
    
    private func toggleTrackSelection(_ track: Track) {
        guard let id = track.id else { return }
        if selectedTracks.contains(id) {
            selectedTracks.remove(id)
        } else {
            selectedTracks.insert(id)
        }
    }
}

struct TagEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var libraryController: LibraryController
    let track: Track
    @State private var tagsText: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Track") {
                    Text(track.displayTitle)
                        .font(.headline)
                    if let artist = track.artist {
                        Text(artist)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Tags") {
                    TextField("Enter tags separated by commas", text: $tagsText, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Text("Use tags to organize and find your tracks. Separate multiple tags with commas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        libraryController.updateTrackTags(track, tags: tagsText)
                        dismiss()
                    }
                }
            }
            .onAppear {
                tagsText = track.tags ?? ""
            }
        }
    }
}

struct AddToPlaylistView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var libraryController: LibraryController
    let track: Track
    @State private var showingNewPlaylist = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if libraryController.playlists.isEmpty {
                    ContentUnavailableView {
                        Label("No Playlists", systemImage: "music.note.list")
                    } description: {
                        Text("Create a playlist to add this track.")
                    } actions: {
                        Button("Create Playlist") {
                            showingNewPlaylist = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(libraryController.playlists, id: \.id) { playlist in
                        Button {
                            libraryController.addTrackToPlaylist(track, playlist: playlist)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(playlist.displayName)
                                        .foregroundStyle(.primary)
                                    Text(playlist.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.accent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewPlaylist = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Playlist", isPresented: $showingNewPlaylist) {
                TextField("Playlist name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) {
                    newPlaylistName = ""
                }
                Button("Create") {
                    if !newPlaylistName.isEmpty {
                        libraryController.createPlaylist(name: newPlaylistName)
                        newPlaylistName = ""
                    }
                }
            }
        }
    }
}

struct AddMultipleToPlaylistView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var libraryController: LibraryController
    let tracks: [Track]
    let onComplete: () -> Void
    @State private var showingNewPlaylist = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if libraryController.playlists.isEmpty {
                    ContentUnavailableView {
                        Label("No Playlists", systemImage: "music.note.list")
                    } description: {
                        Text("Create a playlist to add \(tracks.count) tracks.")
                    } actions: {
                        Button("Create Playlist") {
                            showingNewPlaylist = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(libraryController.playlists, id: \.id) { playlist in
                        Button {
                            for track in tracks {
                                libraryController.addTrackToPlaylist(track, playlist: playlist)
                            }
                            dismiss()
                            onComplete()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(playlist.displayName)
                                        .foregroundStyle(.primary)
                                    Text(playlist.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.accent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add \(tracks.count) Tracks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewPlaylist = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Playlist", isPresented: $showingNewPlaylist) {
                TextField("Playlist name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) {
                    newPlaylistName = ""
                }
                Button("Create") {
                    if !newPlaylistName.isEmpty {
                        libraryController.createPlaylist(name: newPlaylistName)
                        newPlaylistName = ""
                    }
                }
            }
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(LibraryController.shared)
        .environmentObject(AudioPlaybackEngine.shared)
}

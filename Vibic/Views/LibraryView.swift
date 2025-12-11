import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var libraryController: LibraryController
    @EnvironmentObject var playbackEngine: AudioPlaybackEngine
    @State private var searchText = ""
    @State private var showingTagEditor = false
    @State private var selectedTrack: Track?
    @State private var showingAddToPlaylist = false
    
    var filteredTracks: [Track] {
        libraryController.searchTracks(query: searchText)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            libraryController.validateLibrary()
                        } label: {
                            Label("Validate Library", systemImage: "checkmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
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
        }
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
            ForEach(filteredTracks, id: \.id) { track in
                TrackRowView(track: track)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        playbackEngine.playTrack(track, in: filteredTracks)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
                    .swipeActions(edge: .leading) {
                        Button {
                            selectedTrack = track
                            showingTagEditor = true
                        } label: {
                            Label("Tags", systemImage: "tag")
                        }
                        .tint(.orange)
                    }
                    .contextMenu {
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
        .listStyle(.plain)
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

#Preview {
    LibraryView()
        .environmentObject(LibraryController.shared)
        .environmentObject(AudioPlaybackEngine.shared)
}

import SwiftUI

struct PlaylistView: View {
    @EnvironmentObject var libraryController: LibraryController
    @EnvironmentObject var playbackEngine: AudioPlaybackEngine
    @State private var showingNewPlaylist = false
    @State private var newPlaylistName = ""
    @State private var searchText = ""
    
    var filteredPlaylists: [Playlist] {
        libraryController.searchPlaylists(query: searchText)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if libraryController.playlists.isEmpty {
                    emptyStateView
                } else {
                    playlistListView
                }
            }
            .navigationTitle("Playlists")
            .searchable(text: $searchText, prompt: "Search playlists")
            .toolbar {
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
            .refreshable {
                libraryController.refreshPlaylists()
            }
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Playlists", systemImage: "music.note.list")
        } description: {
            Text("Create playlists to organize your music.")
        } actions: {
            Button("Create Playlist") {
                showingNewPlaylist = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var playlistListView: some View {
        List {
            ForEach(filteredPlaylists, id: \.id) { playlist in
                NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                    PlaylistRowView(playlist: playlist)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        libraryController.deletePlaylist(playlist)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button {
                        let tracks = libraryController.getPlaylistTracks(playlist)
                        if let firstTrack = tracks.first {
                            playbackEngine.playTrack(firstTrack, in: tracks)
                        }
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    .disabled(playlist.trackCount == 0)
                    
                    Button {
                        let tracks = libraryController.getPlaylistTracks(playlist).shuffled()
                        if let firstTrack = tracks.first {
                            playbackEngine.playTrack(firstTrack, in: tracks)
                        }
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .disabled(playlist.trackCount == 0)
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        libraryController.deletePlaylist(playlist)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

struct PlaylistRowView: View {
    let playlist: Playlist
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.2))
                Image(systemName: "music.note.list")
                    .font(.title2)
                    .foregroundStyle(.accent)
            }
            .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(playlist.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PlaylistDetailView: View {
    @EnvironmentObject var libraryController: LibraryController
    @EnvironmentObject var playbackEngine: AudioPlaybackEngine
    @ObservedObject var playlist: Playlist
    @State private var showingRename = false
    @State private var newName = ""
    @State private var isEditing = false
    
    var tracks: [Track] {
        libraryController.getPlaylistTracks(playlist)
    }
    
    var body: some View {
        List {
            if !tracks.isEmpty {
                Section {
                    HStack(spacing: 12) {
                        Button {
                            if let firstTrack = tracks.first {
                                playbackEngine.playTrack(firstTrack, in: tracks)
                            }
                        } label: {
                            Label("Play", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button {
                            let shuffled = tracks.shuffled()
                            if let firstTrack = shuffled.first {
                                playbackEngine.playTrack(firstTrack, in: shuffled)
                            }
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            
            Section {
                if tracks.isEmpty {
                    ContentUnavailableView {
                        Label("Empty Playlist", systemImage: "music.note")
                    } description: {
                        Text("Add tracks from your library to this playlist.")
                    }
                } else {
                    ForEach(playlist.orderedItems, id: \.id) { item in
                        if let track = item.track {
                            TrackRowView(track: track)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    playbackEngine.playTrack(track, in: tracks)
                                }
                        }
                    }
                    .onDelete { indexSet in
                        deleteItems(at: indexSet)
                    }
                    .onMove { source, destination in
                        libraryController.reorderPlaylistItems(playlist, fromOffsets: source, toOffset: destination)
                    }
                }
            } header: {
                if !tracks.isEmpty {
                    Text("\(tracks.count) tracks • \(playlist.displayDuration)")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(playlist.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        newName = playlist.name ?? ""
                        showingRename = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    
                    EditButton()
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Rename Playlist", isPresented: $showingRename) {
            TextField("Playlist name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if !newName.isEmpty {
                    libraryController.renamePlaylist(playlist, name: newName)
                }
            }
        }
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
    }
    
    private func deleteItems(at offsets: IndexSet) {
        let items = playlist.orderedItems
        for index in offsets {
            if index < items.count {
                libraryController.removeTrackFromPlaylist(items[index])
            }
        }
    }
}

#Preview {
    PlaylistView()
        .environmentObject(LibraryController.shared)
        .environmentObject(AudioPlaybackEngine.shared)
}

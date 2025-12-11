import Foundation
import CoreData

final class PlaylistManager {
    static let shared = PlaylistManager()
    
    private let coreDataManager = CoreDataManager.shared
    
    private init() {}
    
    // MARK: - Playlist CRUD Operations
    
    func createPlaylist(name: String) -> Playlist {
        return coreDataManager.createPlaylist(name: name)
    }
    
    func getAllPlaylists() -> [Playlist] {
        return coreDataManager.fetchAllPlaylists()
    }
    
    func getPlaylist(by id: UUID) -> Playlist? {
        return coreDataManager.fetchPlaylist(by: id)
    }
    
    func deletePlaylist(_ playlist: Playlist) {
        coreDataManager.deletePlaylist(playlist)
    }
    
    func renamePlaylist(_ playlist: Playlist, newName: String) {
        coreDataManager.renamePlaylist(playlist, name: newName)
    }
    
    // MARK: - Track Management in Playlists
    
    func addTrack(_ track: Track, to playlist: Playlist) {
        let existingItems = playlist.orderedItems
        let alreadyExists = existingItems.contains { $0.track?.id == track.id }
        
        if !alreadyExists {
            coreDataManager.addTrackToPlaylist(track, playlist: playlist)
        }
    }
    
    func addTracks(_ tracks: [Track], to playlist: Playlist) {
        for track in tracks {
            addTrack(track, to: playlist)
        }
    }
    
    func removeTrack(at index: Int, from playlist: Playlist) {
        let items = playlist.orderedItems
        guard index >= 0 && index < items.count else { return }
        coreDataManager.removeItemFromPlaylist(items[index])
    }
    
    func removeItem(_ item: PlaylistItem) {
        coreDataManager.removeItemFromPlaylist(item)
    }
    
    // MARK: - Reordering
    
    func moveTrack(in playlist: Playlist, from sourceIndex: Int, to destinationIndex: Int) {
        let fromOffsets = IndexSet(integer: sourceIndex)
        coreDataManager.reorderPlaylistItems(playlist, fromOffsets: fromOffsets, toOffset: destinationIndex)
    }
    
    func reorderTracks(in playlist: Playlist, fromOffsets: IndexSet, toOffset: Int) {
        coreDataManager.reorderPlaylistItems(playlist, fromOffsets: fromOffsets, toOffset: toOffset)
    }
    
    // MARK: - Playlist Queries
    
    func getTracksInPlaylist(_ playlist: Playlist) -> [Track] {
        return playlist.orderedItems.compactMap { $0.track }
    }
    
    func getPlaylistItemsInPlaylist(_ playlist: Playlist) -> [PlaylistItem] {
        return playlist.orderedItems
    }
    
    func trackCount(in playlist: Playlist) -> Int {
        return playlist.items?.count ?? 0
    }
    
    func totalDuration(of playlist: Playlist) -> Double {
        return getTracksInPlaylist(playlist).reduce(0) { $0 + $1.duration }
    }
    
    func containsTrack(_ track: Track, in playlist: Playlist) -> Bool {
        return playlist.orderedItems.contains { $0.track?.id == track.id }
    }
    
    // MARK: - Playlist Utilities
    
    func duplicatePlaylist(_ playlist: Playlist, newName: String) -> Playlist {
        let newPlaylist = createPlaylist(name: newName)
        let tracks = getTracksInPlaylist(playlist)
        addTracks(tracks, to: newPlaylist)
        return newPlaylist
    }
    
    func mergePlaylists(_ playlists: [Playlist], into name: String) -> Playlist {
        let newPlaylist = createPlaylist(name: name)
        var addedTrackIDs: Set<UUID> = []
        
        for playlist in playlists {
            for track in getTracksInPlaylist(playlist) {
                if let trackID = track.id, !addedTrackIDs.contains(trackID) {
                    addTrack(track, to: newPlaylist)
                    addedTrackIDs.insert(trackID)
                }
            }
        }
        
        return newPlaylist
    }
    
    func clearPlaylist(_ playlist: Playlist) {
        for item in playlist.orderedItems {
            coreDataManager.removeItemFromPlaylist(item)
        }
    }
    
    // MARK: - Shuffle Support
    
    func getShuffledTracks(from playlist: Playlist) -> [Track] {
        return getTracksInPlaylist(playlist).shuffled()
    }
}

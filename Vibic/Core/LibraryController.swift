import Foundation
import Combine
import SwiftUI

final class LibraryController: ObservableObject {
    static let shared = LibraryController()
    
    private let coreDataManager = CoreDataManager.shared
    private let audioFileManager = AudioFileManager.shared
    private let playlistManager = PlaylistManager.shared
    
    @Published var tracks: [Track] = []
    @Published var playlists: [Playlist] = []
    @Published var isImporting = false
    @Published var importError: String?
    
    private init() {
        loadLibrary()
    }
    
    // MARK: - Library Loading
    
    func loadLibrary() {
        tracks = coreDataManager.fetchAllTracks()
        playlists = coreDataManager.fetchAllPlaylists()
    }
    
    func refreshTracks() {
        tracks = coreDataManager.fetchAllTracks()
    }
    
    func refreshPlaylists() {
        playlists = coreDataManager.fetchAllPlaylists()
    }
    
    // MARK: - File Import
    
    func importFile(from url: URL) {
        isImporting = true
        importError = nil
        
        audioFileManager.importFile(from: url) { [weak self] result in
            DispatchQueue.main.async {
                self?.isImporting = false
                switch result {
                case .success(let fileInfo):
                    self?.registerTrack(from: fileInfo)
                case .failure(let error):
                    self?.importError = error.localizedDescription
                }
            }
        }
    }
    
    func importFiles(from urls: [URL]) {
        isImporting = true
        importError = nil
        
        audioFileManager.importFiles(from: urls) { [weak self] results in
            DispatchQueue.main.async {
                self?.isImporting = false
                var successCount = 0
                var errorMessages: [String] = []
                
                for result in results {
                    switch result {
                    case .success(let fileInfo):
                        self?.registerTrack(from: fileInfo)
                        successCount += 1
                    case .failure(let error):
                        errorMessages.append(error.localizedDescription)
                    }
                }
                
                if !errorMessages.isEmpty {
                    self?.importError = "Imported \(successCount) files. Errors: \(errorMessages.joined(separator: ", "))"
                }
            }
        }
    }
    
    private func registerTrack(from fileInfo: AudioFileInfo) {
        if coreDataManager.fetchTrack(by: fileInfo.filePath) != nil {
            return
        }
        
        let _ = coreDataManager.createTrack(
            title: fileInfo.title,
            artist: fileInfo.artist,
            filePath: fileInfo.filePath,
            duration: fileInfo.duration,
            fileSize: fileInfo.fileSize,
            tags: nil,
            artworkData: fileInfo.artworkData
        )
        
        refreshTracks()
    }
    
    // MARK: - Track Operations
    
    func deleteTrack(_ track: Track) {
        if let filePath = track.filePath {
            _ = audioFileManager.deleteFile(at: filePath)
        }
        coreDataManager.deleteTrack(track)
        refreshTracks()
    }
    
    func updateTrackTags(_ track: Track, tags: String) {
        coreDataManager.updateTrackTags(track, tags: tags)
        refreshTracks()
    }
    
    func getTrack(by id: UUID) -> Track? {
        return coreDataManager.fetchTrack(by: id)
    }
    
    // MARK: - Playlist Operations
    
    func createPlaylist(name: String) {
        _ = coreDataManager.createPlaylist(name: name)
        refreshPlaylists()
    }
    
    func deletePlaylist(_ playlist: Playlist) {
        coreDataManager.deletePlaylist(playlist)
        refreshPlaylists()
    }
    
    func renamePlaylist(_ playlist: Playlist, name: String) {
        coreDataManager.renamePlaylist(playlist, name: name)
        refreshPlaylists()
    }
    
    func addTrackToPlaylist(_ track: Track, playlist: Playlist) {
        coreDataManager.addTrackToPlaylist(track, playlist: playlist)
        refreshPlaylists()
    }
    
    func removeTrackFromPlaylist(_ item: PlaylistItem) {
        coreDataManager.removeItemFromPlaylist(item)
        refreshPlaylists()
    }
    
    func reorderPlaylistItems(_ playlist: Playlist, fromOffsets: IndexSet, toOffset: Int) {
        coreDataManager.reorderPlaylistItems(playlist, fromOffsets: fromOffsets, toOffset: toOffset)
        refreshPlaylists()
    }
    
    func getPlaylistTracks(_ playlist: Playlist) -> [Track] {
        return playlist.orderedItems.compactMap { $0.track }
    }
    
    // MARK: - Search
    
    func searchTracks(query: String) -> [Track] {
        guard !query.isEmpty else { return tracks }
        let lowercasedQuery = query.lowercased()
        return tracks.filter { track in
            (track.title?.lowercased().contains(lowercasedQuery) ?? false) ||
            (track.artist?.lowercased().contains(lowercasedQuery) ?? false) ||
            (track.tags?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }
    
    func searchPlaylists(query: String) -> [Playlist] {
        guard !query.isEmpty else { return playlists }
        let lowercasedQuery = query.lowercased()
        return playlists.filter { playlist in
            playlist.name?.lowercased().contains(lowercasedQuery) ?? false
        }
    }
    
    // MARK: - Validation
    
    func validateLibrary() {
        for track in tracks {
            if let filePath = track.filePath, !audioFileManager.fileExists(at: filePath) {
                coreDataManager.deleteTrack(track)
            }
        }
        refreshTracks()
    }
}

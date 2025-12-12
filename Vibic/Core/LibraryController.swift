import Foundation
import Combine
import SwiftUI

enum FolderImportError: LocalizedError {
    case noAudioFiles
    
    var errorDescription: String? {
        switch self {
        case .noAudioFiles:
            return "No audio files found in the selected folder"
        }
    }
}

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
    
    func importFolderAsPlaylist(from folderURL: URL, completion: @escaping (Result<(playlistName: String, trackCount: Int), Error>) -> Void) {
        isImporting = true
        importError = nil
        
        let shouldStopAccessing = folderURL.startAccessingSecurityScopedResource()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer {
                if shouldStopAccessing {
                    folderURL.stopAccessingSecurityScopedResource()
                }
            }
            
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            let folderName = folderURL.lastPathComponent
            
            // Get all audio files in the folder
            var audioURLs: [URL] = []
            
            if let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    if AudioFileManager.isAudioFile(fileURL) {
                        audioURLs.append(fileURL)
                    }
                }
            }
            
            guard !audioURLs.isEmpty else {
                DispatchQueue.main.async {
                    self.isImporting = false
                    completion(.failure(FolderImportError.noAudioFiles))
                }
                return
            }
            
            // Import all audio files
            self.audioFileManager.importFiles(from: audioURLs) { results in
                DispatchQueue.main.async {
                    var importedTracks: [Track] = []
                    
                    for result in results {
                        if case .success(let fileInfo) = result {
                            // Check if track already exists
                            if let existingTrack = self.coreDataManager.fetchTrack(by: fileInfo.filePath) {
                                importedTracks.append(existingTrack)
                            } else {
                                let track = self.coreDataManager.createTrack(
                                    title: fileInfo.title,
                                    artist: fileInfo.artist,
                                    filePath: fileInfo.filePath,
                                    duration: fileInfo.duration,
                                    fileSize: fileInfo.fileSize,
                                    tags: nil,
                                    artworkData: fileInfo.artworkData
                                )
                                importedTracks.append(track)
                            }
                        }
                    }
                    
                    // Create playlist with folder name
                    let playlist = self.coreDataManager.createPlaylist(name: folderName)
                    
                    // Add tracks to playlist
                    for track in importedTracks {
                        self.coreDataManager.addTrackToPlaylist(track, playlist: playlist)
                    }
                    
                    self.refreshTracks()
                    self.refreshPlaylists()
                    self.isImporting = false
                    
                    completion(.success((playlistName: folderName, trackCount: importedTracks.count)))
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
    
    // MARK: - Streaming Track Import
    
    func addStreamedTrack(from searchResult: YouTubeSearchResult, completion: @escaping (Track?) -> Void) {
        // Check if already in library
        if let existing = coreDataManager.fetchTrackByVideoId(searchResult.id) {
            completion(existing)
            return
        }
        
        Task {
            // Fetch thumbnail
            let artworkData = await YouTubeService.shared.getThumbnail(videoId: searchResult.id)
            
            await MainActor.run {
                let track = coreDataManager.createStreamedTrack(
                    title: searchResult.title,
                    artist: searchResult.artist,
                    videoId: searchResult.id,
                    duration: searchResult.durationSeconds,
                    artworkData: artworkData
                )
                refreshTracks()
                completion(track)
            }
        }
    }
    
    func isTrackInLibrary(videoId: String) -> Bool {
        return coreDataManager.fetchTrackByVideoId(videoId) != nil
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

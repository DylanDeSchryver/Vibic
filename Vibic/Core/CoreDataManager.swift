import Foundation
import CoreData

final class CoreDataManager {
    static let shared = CoreDataManager()
    
    let persistentContainer: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    private init() {
        persistentContainer = NSPersistentContainer(name: "VibicModel")
        persistentContainer.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    func save() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Error saving context: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - Track Operations
    
    func createTrack(
        title: String,
        artist: String?,
        filePath: String,
        duration: Double,
        fileSize: Int64,
        tags: String?,
        artworkData: Data? = nil
    ) -> Track {
        let track = Track(context: viewContext)
        track.id = UUID()
        track.title = title
        track.artist = artist
        track.filePath = filePath
        track.duration = duration
        track.fileSize = fileSize
        track.tags = tags
        track.artworkData = artworkData
        track.addedDate = Date()
        save()
        return track
    }
    
    func fetchAllTracks() -> [Track] {
        let request: NSFetchRequest<Track> = Track.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Track.addedDate, ascending: false)]
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching tracks: \(error)")
            return []
        }
    }
    
    func fetchTrack(by id: UUID) -> Track? {
        let request: NSFetchRequest<Track> = Track.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        do {
            return try viewContext.fetch(request).first
        } catch {
            print("Error fetching track: \(error)")
            return nil
        }
    }
    
    func fetchTrack(by filePath: String) -> Track? {
        let request: NSFetchRequest<Track> = Track.fetchRequest()
        request.predicate = NSPredicate(format: "filePath == %@", filePath)
        request.fetchLimit = 1
        do {
            return try viewContext.fetch(request).first
        } catch {
            print("Error fetching track: \(error)")
            return nil
        }
    }
    
    func deleteTrack(_ track: Track) {
        viewContext.delete(track)
        save()
    }
    
    func updateTrackTags(_ track: Track, tags: String) {
        track.tags = tags
        save()
    }
    
    // MARK: - Streaming Track Operations
    
    func createStreamedTrack(
        title: String,
        artist: String?,
        videoId: String,
        duration: Double,
        artworkData: Data?
    ) -> Track {
        let track = Track(context: viewContext)
        track.id = UUID()
        track.title = title
        track.artist = artist
        track.videoId = videoId
        track.isStreamed = true
        track.duration = duration
        track.artworkData = artworkData
        track.addedDate = Date()
        track.fileSize = 0
        save()
        return track
    }
    
    func fetchTrackByVideoId(_ videoId: String) -> Track? {
        let request: NSFetchRequest<Track> = Track.fetchRequest()
        request.predicate = NSPredicate(format: "videoId == %@", videoId)
        request.fetchLimit = 1
        do {
            return try viewContext.fetch(request).first
        } catch {
            print("Error fetching track by videoId: \(error)")
            return nil
        }
    }
    
    // MARK: - Playlist Operations
    
    func createPlaylist(name: String) -> Playlist {
        let playlist = Playlist(context: viewContext)
        playlist.id = UUID()
        playlist.name = name
        playlist.createdDate = Date()
        save()
        return playlist
    }
    
    func fetchAllPlaylists() -> [Playlist] {
        let request: NSFetchRequest<Playlist> = Playlist.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Playlist.createdDate, ascending: false)]
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching playlists: \(error)")
            return []
        }
    }
    
    func fetchPlaylist(by id: UUID) -> Playlist? {
        let request: NSFetchRequest<Playlist> = Playlist.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        do {
            return try viewContext.fetch(request).first
        } catch {
            print("Error fetching playlist: \(error)")
            return nil
        }
    }
    
    func deletePlaylist(_ playlist: Playlist) {
        viewContext.delete(playlist)
        save()
    }
    
    func renamePlaylist(_ playlist: Playlist, name: String) {
        playlist.name = name
        save()
    }
    
    // MARK: - PlaylistItem Operations
    
    func addTrackToPlaylist(_ track: Track, playlist: Playlist) {
        let item = PlaylistItem(context: viewContext)
        item.id = UUID()
        item.track = track
        item.playlist = playlist
        item.order = Int32((playlist.items?.count ?? 0))
        save()
    }
    
    func removeItemFromPlaylist(_ item: PlaylistItem) {
        viewContext.delete(item)
        save()
    }
    
    func reorderPlaylistItems(_ playlist: Playlist, fromOffsets: IndexSet, toOffset: Int) {
        var items = playlist.orderedItems
        items.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (index, item) in items.enumerated() {
            item.order = Int32(index)
        }
        save()
    }
    
    func getPlaylistItems(for playlist: Playlist) -> [PlaylistItem] {
        return playlist.orderedItems
    }
}

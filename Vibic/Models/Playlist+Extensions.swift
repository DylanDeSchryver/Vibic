import Foundation
import CoreData

extension Playlist {
    var displayName: String {
        name ?? "Untitled Playlist"
    }
    
    var trackCount: Int {
        items?.count ?? 0
    }
    
    var orderedItems: [PlaylistItem] {
        guard let items = items as? Set<PlaylistItem> else { return [] }
        return items.sorted { $0.order < $1.order }
    }
    
    var tracks: [Track] {
        orderedItems.compactMap { $0.track }
    }
    
    var totalDuration: Double {
        tracks.reduce(0) { $0 + $1.duration }
    }
    
    var displayDuration: String {
        let total = totalDuration
        if total >= 3600 {
            let hours = Int(total) / 3600
            let minutes = (Int(total) % 3600) / 60
            return "\(hours)h \(minutes)m"
        } else {
            let minutes = Int(total) / 60
            let seconds = Int(total) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var subtitle: String {
        let count = trackCount
        let trackText = count == 1 ? "track" : "tracks"
        return "\(count) \(trackText) • \(displayDuration)"
    }
}


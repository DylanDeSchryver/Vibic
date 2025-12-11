import Foundation
import CoreData
import UIKit

extension Track {
    var artworkImage: UIImage? {
        guard let data = artworkData else { return nil }
        return UIImage(data: data)
    }
    
    var displayTitle: String {
        title ?? "Unknown Track"
    }
    
    var displayArtist: String {
        artist ?? "Unknown Artist"
    }
    
    var displayDuration: String {
        formatDuration(duration)
    }
    
    var displayFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var tagsArray: [String] {
        get {
            guard let tags = tags, !tags.isEmpty else { return [] }
            return tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        set {
            tags = newValue.joined(separator: ", ")
        }
    }
    
    var fileURL: URL? {
        guard let filePath = filePath else { return nil }
        return URL(fileURLWithPath: filePath)
    }
    
    var fileExists: Bool {
        guard let filePath = filePath else { return false }
        return FileManager.default.fileExists(atPath: filePath)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        guard !duration.isNaN && !duration.isInfinite else { return "0:00" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


import Foundation
import AVFoundation
import UniformTypeIdentifiers

final class AudioFileManager {
    static let shared = AudioFileManager()
    
    private let fileManager = FileManager.default
    
    private var audioDirectory: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioDir = documentsDirectory.appendingPathComponent("AudioFiles", isDirectory: true)
        if !fileManager.fileExists(atPath: audioDir.path) {
            try? fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true)
        }
        return audioDir
    }
    
    private init() {}
    
    // MARK: - Supported Audio Types
    
    static let supportedAudioExtensions: Set<String> = ["mp3", "m4a", "wav", "aac", "flac", "aiff", "caf"]
    
    static func isAudioFile(_ url: URL) -> Bool {
        return supportedAudioExtensions.contains(url.pathExtension.lowercased())
    }
    
    // MARK: - File Import
    
    func importFile(from sourceURL: URL, completion: @escaping (Result<AudioFileInfo, Error>) -> Void) {
        let shouldStopAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        guard Self.isAudioFile(sourceURL) else {
            completion(.failure(AudioFileError.unsupportedFormat))
            return
        }
        
        let fileName = sourceURL.lastPathComponent
        let destinationURL = audioDirectory.appendingPathComponent(fileName)
        
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            
            extractMetadata(from: destinationURL) { result in
                switch result {
                case .success(var fileInfo):
                    fileInfo.filePath = destinationURL.path
                    completion(.success(fileInfo))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    func importFiles(from urls: [URL], completion: @escaping ([Result<AudioFileInfo, Error>]) -> Void) {
        let group = DispatchGroup()
        var results: [Result<AudioFileInfo, Error>] = []
        let lock = NSLock()
        
        for url in urls {
            group.enter()
            importFile(from: url) { result in
                lock.lock()
                results.append(result)
                lock.unlock()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }
    
    // MARK: - Metadata Extraction
    
    func extractMetadata(from url: URL, completion: @escaping (Result<AudioFileInfo, Error>) -> Void) {
        let asset = AVURLAsset(url: url)
        
        Task {
            do {
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                
                var title = url.deletingPathExtension().lastPathComponent
                var artist: String?
                var artworkData: Data?
                
                let metadata = try await asset.load(.commonMetadata)
                
                for item in metadata {
                    if let commonKey = item.commonKey {
                        switch commonKey {
                        case .commonKeyTitle:
                            if let value = try await item.load(.stringValue) {
                                title = value
                            }
                        case .commonKeyArtist:
                            artist = try await item.load(.stringValue)
                        case .commonKeyArtwork:
                            if let data = try await item.load(.dataValue) {
                                artworkData = data
                            }
                        default:
                            break
                        }
                    }
                }
                
                // Also check ID3 metadata for artwork if not found in common metadata
                if artworkData == nil {
                    let id3Metadata = try await asset.load(.metadata)
                    for item in id3Metadata {
                        if let key = item.identifier,
                           key == .id3MetadataAttachedPicture || 
                           key == .iTunesMetadataCoverArt ||
                           key == .quickTimeMetadataArtwork {
                            if let data = try await item.load(.dataValue) {
                                artworkData = data
                                break
                            }
                        }
                    }
                }
                
                let attributes = try self.fileManager.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                let fileInfo = AudioFileInfo(
                    title: title,
                    artist: artist,
                    filePath: url.path,
                    duration: durationSeconds,
                    fileSize: fileSize,
                    artworkData: artworkData
                )
                
                await MainActor.run {
                    completion(.success(fileInfo))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - File Management
    
    func deleteFile(at path: String) -> Bool {
        do {
            try fileManager.removeItem(atPath: path)
            return true
        } catch {
            print("Error deleting file: \(error)")
            return false
        }
    }
    
    func fileExists(at path: String) -> Bool {
        return fileManager.fileExists(atPath: path)
    }
    
    func getFileURL(for path: String) -> URL {
        return URL(fileURLWithPath: path)
    }
    
    func listImportedFiles() -> [URL] {
        do {
            let files = try fileManager.contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: nil)
            return files.filter { Self.isAudioFile($0) }
        } catch {
            print("Error listing files: \(error)")
            return []
        }
    }
    
    // MARK: - Document Picker Support
    
    func getDocumentsDirectory() -> URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func getAudioDirectory() -> URL {
        return audioDirectory
    }
}

// MARK: - Supporting Types

struct AudioFileInfo {
    var title: String
    var artist: String?
    var filePath: String
    var duration: Double
    var fileSize: Int64
    var artworkData: Data?
}

enum AudioFileError: LocalizedError {
    case unsupportedFormat
    case fileNotFound
    case importFailed
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported audio format"
        case .fileNotFound:
            return "File not found"
        case .importFailed:
            return "Failed to import file"
        }
    }
}

import Foundation
import AVFoundation

// MARK: - YouTube Search Result

struct YouTubeSearchResult: Identifiable, Codable {
    let id: String // videoId
    let title: String
    let artist: String
    let thumbnailURL: String
    let duration: String?
    
    var durationSeconds: TimeInterval {
        guard let duration = duration else { return 0 }
        // Parse ISO 8601 duration or simple format
        return parseDuration(duration)
    }
    
    private func parseDuration(_ duration: String) -> TimeInterval {
        // Handle formats like "3:45" or "PT3M45S"
        if duration.contains(":") {
            let parts = duration.split(separator: ":")
            if parts.count == 2 {
                let minutes = Double(parts[0]) ?? 0
                let seconds = Double(parts[1]) ?? 0
                return minutes * 60 + seconds
            } else if parts.count == 3 {
                let hours = Double(parts[0]) ?? 0
                let minutes = Double(parts[1]) ?? 0
                let seconds = Double(parts[2]) ?? 0
                return hours * 3600 + minutes * 60 + seconds
            }
        }
        return 0
    }
}

// MARK: - Stream Info

struct StreamInfo {
    let audioURL: URL
    let expiresAt: Date?
}

// MARK: - YouTube Service

final class YouTubeService {
    static let shared = YouTubeService()
    
    private let session: URLSession
    private var streamCache: [String: (url: URL, expires: Date)] = [:]
    
    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        ]
        session = URLSession(configuration: config)
    }
    
    // MARK: - Search
    
    func search(query: String) async throws -> [YouTubeSearchResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        // Use Piped API (open-source YouTube frontend) for search
        let pipedInstances = [
            "https://pipedapi.kavin.rocks",
            "https://pipedapi.adminforge.de",
            "https://api.piped.yt",
            "https://pipedapi.in.projectsegfau.lt",
            "https://pipedapi.darkness.services",
            "https://pipedapi.drgns.space"
        ]
        
        var lastError: Error?
        
        // Try with music filter first, then without
        let filters = ["music_songs", "videos", ""]
        
        for filter in filters {
            for instance in pipedInstances {
                do {
                    let filterParam = filter.isEmpty ? "" : "&filter=\(filter)"
                    let urlString = "\(instance)/search?q=\(encodedQuery)\(filterParam)"
                    guard let url = URL(string: urlString) else { continue }
                    
                    let (data, response) = try await session.data(from: url)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else { continue }
                    
                    let results = try parsePipedSearchResults(data)
                    if !results.isEmpty {
                        return results
                    }
                } catch {
                    lastError = error
                    continue
                }
            }
        }
        
        // Fallback to Invidious API
        return try await searchInvidious(query: encodedQuery)
    }
    
    private func parsePipedSearchResults(_ data: Data) throws -> [YouTubeSearchResult] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { item -> YouTubeSearchResult? in
            guard let urlPath = item["url"] as? String,
                  let title = item["title"] as? String else { return nil }
            
            // Extract video ID from URL path like "/watch?v=xxxxx"
            let videoId: String
            if let range = urlPath.range(of: "v=") {
                videoId = String(urlPath[range.upperBound...].prefix(11))
            } else {
                return nil
            }
            
            let uploaderName = item["uploaderName"] as? String ?? "Unknown Artist"
            let thumbnail = item["thumbnail"] as? String ?? ""
            let duration = item["duration"] as? Int
            
            let durationString: String?
            if let dur = duration {
                let minutes = dur / 60
                let seconds = dur % 60
                durationString = String(format: "%d:%02d", minutes, seconds)
            } else {
                durationString = nil
            }
            
            return YouTubeSearchResult(
                id: videoId,
                title: cleanTitle(title),
                artist: cleanArtist(uploaderName),
                thumbnailURL: thumbnail,
                duration: durationString
            )
        }
    }
    
    private func searchInvidious(query: String) async throws -> [YouTubeSearchResult] {
        let invidiousInstances = [
            "https://inv.nadeko.net",
            "https://invidious.nerdvpn.de",
            "https://invidious.privacyredirect.com",
            "https://invidious.protokolla.fi",
            "https://iv.nboeck.de"
        ]
        
        for instance in invidiousInstances {
            do {
                let urlString = "\(instance)/api/v1/search?q=\(query)&type=video"
                guard let url = URL(string: urlString) else { continue }
                
                let (data, response) = try await session.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else { continue }
                
                guard let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    continue
                }
                
                let results = items.prefix(20).compactMap { item -> YouTubeSearchResult? in
                    guard let videoId = item["videoId"] as? String,
                          let title = item["title"] as? String else { return nil }
                    
                    let author = item["author"] as? String ?? "Unknown Artist"
                    let lengthSeconds = item["lengthSeconds"] as? Int ?? 0
                    
                    let thumbnails = item["videoThumbnails"] as? [[String: Any]]
                    let thumbnail = thumbnails?.first?["url"] as? String ?? ""
                    
                    let minutes = lengthSeconds / 60
                    let seconds = lengthSeconds % 60
                    let durationString = String(format: "%d:%02d", minutes, seconds)
                    
                    return YouTubeSearchResult(
                        id: videoId,
                        title: cleanTitle(title),
                        artist: cleanArtist(author),
                        thumbnailURL: thumbnail,
                        duration: durationString
                    )
                }
                
                if !results.isEmpty {
                    return Array(results)
                }
            } catch {
                continue
            }
        }
        
        throw YouTubeError.searchFailed
    }
    
    // MARK: - Stream URL Extraction
    
    func getStreamURL(videoId: String) async throws -> URL {
        // Check cache first
        if let cached = streamCache[videoId], cached.expires > Date() {
            return cached.url
        }
        
        // Try Piped API first
        let pipedInstances = [
            "https://pipedapi.kavin.rocks",
            "https://pipedapi.adminforge.de",
            "https://api.piped.yt",
            "https://pipedapi.in.projectsegfau.lt",
            "https://pipedapi.darkness.services",
            "https://pipedapi.drgns.space"
        ]
        
        for instance in pipedInstances {
            do {
                let urlString = "\(instance)/streams/\(videoId)"
                guard let url = URL(string: urlString) else { continue }
                
                let (data, response) = try await session.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else { continue }
                
                if let streamURL = try parseStreamURL(from: data) {
                    // Cache for 5 hours (streams typically expire in 6)
                    let expires = Date().addingTimeInterval(5 * 60 * 60)
                    streamCache[videoId] = (streamURL, expires)
                    return streamURL
                }
            } catch {
                continue
            }
        }
        
        throw YouTubeError.streamExtractionFailed
    }
    
    private func parseStreamURL(from data: Data) throws -> URL? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Look for audio streams first (better for music)
        if let audioStreams = json["audioStreams"] as? [[String: Any]] {
            // Sort by bitrate, prefer highest quality
            let sorted = audioStreams.sorted { a, b in
                (a["bitrate"] as? Int ?? 0) > (b["bitrate"] as? Int ?? 0)
            }
            
            for stream in sorted {
                if let urlString = stream["url"] as? String,
                   let url = URL(string: urlString) {
                    return url
                }
            }
        }
        
        // Fallback to HLS stream
        if let hlsString = json["hls"] as? String,
           let hlsURL = URL(string: hlsString) {
            return hlsURL
        }
        
        return nil
    }
    
    // MARK: - Thumbnail
    
    func getThumbnail(videoId: String) async -> Data? {
        let thumbnailURLs = [
            "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg",
            "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg",
            "https://img.youtube.com/vi/\(videoId)/mqdefault.jpg"
        ]
        
        for urlString in thumbnailURLs {
            guard let url = URL(string: urlString) else { continue }
            
            do {
                let (data, response) = try await session.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      data.count > 1000 else { continue } // Skip placeholder images
                return data
            } catch {
                continue
            }
        }
        
        return nil
    }
    
    // MARK: - Helpers
    
    private func cleanTitle(_ title: String) -> String {
        var cleaned = title
        // Remove common suffixes
        let patterns = [
            " \\(Official.*\\)",
            " \\[Official.*\\]",
            " \\(Lyric.*\\)",
            " \\[Lyric.*\\]",
            " \\(Audio.*\\)",
            " \\[Audio.*\\]",
            " \\| .*",
            " - Topic$"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: ""
                )
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    private func cleanArtist(_ artist: String) -> String {
        var cleaned = artist
        // Remove common suffixes
        let suffixes = [" - Topic", " Official", " VEVO", "VEVO"]
        for suffix in suffixes {
            if cleaned.hasSuffix(suffix) {
                cleaned = String(cleaned.dropLast(suffix.count))
            }
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Cache Management
    
    func clearExpiredCache() {
        let now = Date()
        streamCache = streamCache.filter { $0.value.expires > now }
    }
}

// MARK: - Errors

enum YouTubeError: LocalizedError {
    case searchFailed
    case streamExtractionFailed
    case invalidVideoId
    
    var errorDescription: String? {
        switch self {
        case .searchFailed:
            return "Failed to search for music. Please try again."
        case .streamExtractionFailed:
            return "Failed to load stream. Please try again."
        case .invalidVideoId:
            return "Invalid video ID."
        }
    }
}

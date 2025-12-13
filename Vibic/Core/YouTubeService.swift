import Foundation
import AVFoundation
import YouTubeKit

// MARK: - YouTube Search Result

struct YouTubeSearchResult: Identifiable, Codable, Hashable {
    let id: String // videoId
    let title: String
    let artist: String
    let thumbnailURL: String
    let duration: String?
    
    var durationSeconds: TimeInterval {
        guard let duration = duration else { return 0 }
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
        // Handle ISO 8601 duration format PT3M45S
        if duration.hasPrefix("PT") {
            var totalSeconds: Double = 0
            var numberString = ""
            for char in duration.dropFirst(2) {
                if char.isNumber {
                    numberString.append(char)
                } else {
                    let value = Double(numberString) ?? 0
                    switch char {
                    case "H": totalSeconds += value * 3600
                    case "M": totalSeconds += value * 60
                    case "S": totalSeconds += value
                    default: break
                    }
                    numberString = ""
                }
            }
            return totalSeconds
        }
        return 0
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: YouTubeSearchResult, rhs: YouTubeSearchResult) -> Bool {
        lhs.id == rhs.id
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
    
    // YouTube Data API key - user can set this in Settings
    var apiKey: String? {
        get { UserDefaults.standard.string(forKey: "youtubeAPIKey") }
        set { UserDefaults.standard.set(newValue, forKey: "youtubeAPIKey") }
    }
    
    // Piped instances for stream extraction - server-side extraction is much faster
    private let pipedInstances = [
        "https://pipedapi.kavin.rocks",
        "https://api.piped.private.coffee",
        "https://pipedapi.adminforge.de",
        "https://api.piped.yt"
    ]
    
    // Invidious instances for fallback
    private let invidiousInstances = [
        "https://inv.nadeko.net",
        "https://invidious.io.lol"
    ]
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept": "application/json",
            "Accept-Language": "en-US,en;q=0.9"
        ]
        session = URLSession(configuration: config)
    }
    
    // MARK: - Search
    
    func search(query: String) async throws -> [YouTubeSearchResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        // Try YouTube Data API v3 first if API key is configured
        if let apiKey = apiKey, !apiKey.isEmpty {
            do {
                let results = try await searchYouTubeAPI(query: encodedQuery, apiKey: apiKey)
                if !results.isEmpty {
                    return results
                }
            } catch {
                print("[YouTubeService] YouTube API failed: \(error.localizedDescription)")
                // Fall through to try other methods
            }
        }
        
        var lastError: Error = YouTubeError.apiKeyRequired
        
        // Try Piped API as fallback
        let filters = ["music_songs", "videos", ""]
        
        for filter in filters {
            for instance in pipedInstances {
                do {
                    let filterParam = filter.isEmpty ? "" : "&filter=\(filter)"
                    let urlString = "\(instance)/search?q=\(encodedQuery)\(filterParam)"
                    guard let url = URL(string: urlString) else { continue }
                    
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 10
                    
                    let (data, response) = try await session.data(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else { continue }
                    
                    let results = try parsePipedSearchResults(data)
                    if !results.isEmpty {
                        print("[YouTubeService] Search success via Piped: \(instance)")
                        return results
                    }
                } catch {
                    lastError = error
                    print("[YouTubeService] Piped instance failed: \(instance) - \(error.localizedDescription)")
                    continue
                }
            }
        }
        
        // Fallback to Invidious API
        do {
            let results = try await searchInvidious(query: encodedQuery)
            if !results.isEmpty {
                return results
            }
        } catch {
            lastError = error
        }
        
        // If no API key configured and public APIs failed
        if apiKey == nil || apiKey?.isEmpty == true {
            throw YouTubeError.apiKeyRequired
        }
        
        throw lastError
    }
    
    // MARK: - YouTube Data API v3 Search
    
    private func searchYouTubeAPI(query: String, apiKey: String) async throws -> [YouTubeSearchResult] {
        let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&videoCategoryId=10&maxResults=20&q=\(query)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw YouTubeError.searchFailed
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw YouTubeError.searchFailed
        }
        
        if httpResponse.statusCode == 403 {
            throw YouTubeError.apiKeyInvalid
        }
        
        guard httpResponse.statusCode == 200 else {
            throw YouTubeError.searchFailed
        }
        
        return try parseYouTubeAPIResults(data)
    }
    
    private func parseYouTubeAPIResults(_ data: Data) throws -> [YouTubeSearchResult] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { item -> YouTubeSearchResult? in
            guard let id = item["id"] as? [String: Any],
                  let videoId = id["videoId"] as? String,
                  let snippet = item["snippet"] as? [String: Any],
                  let title = snippet["title"] as? String else {
                return nil
            }
            
            let channelTitle = snippet["channelTitle"] as? String ?? "Unknown Artist"
            
            // Get thumbnail
            var thumbnailURL = ""
            if let thumbnails = snippet["thumbnails"] as? [String: Any] {
                if let high = thumbnails["high"] as? [String: Any],
                   let url = high["url"] as? String {
                    thumbnailURL = url
                } else if let medium = thumbnails["medium"] as? [String: Any],
                          let url = medium["url"] as? String {
                    thumbnailURL = url
                }
            }
            
            return YouTubeSearchResult(
                id: videoId,
                title: cleanTitle(title),
                artist: cleanArtist(channelTitle),
                thumbnailURL: thumbnailURL,
                duration: nil // Duration requires an additional API call
            )
        }
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
        var lastError: Error = YouTubeError.searchFailed
        
        for instance in invidiousInstances {
            do {
                let urlString = "\(instance)/api/v1/search?q=\(query)&type=video"
                guard let url = URL(string: urlString) else { continue }
                
                var request = URLRequest(url: url)
                request.timeoutInterval = 10
                
                let (data, response) = try await session.data(for: request)
                
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
                    
                    // Try to get best quality thumbnail
                    let thumbnails = item["videoThumbnails"] as? [[String: Any]]
                    var thumbnail = ""
                    if let thumbs = thumbnails {
                        // Prefer medium quality thumbnail
                        for t in thumbs {
                            if let quality = t["quality"] as? String,
                               quality == "medium" || quality == "high",
                               let urlStr = t["url"] as? String {
                                thumbnail = urlStr
                                break
                            }
                        }
                        // Fallback to first available
                        if thumbnail.isEmpty, let first = thumbs.first?["url"] as? String {
                            thumbnail = first
                        }
                    }
                    
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
                    print("[YouTubeService] Search success via Invidious: \(instance)")
                    return Array(results)
                }
            } catch {
                lastError = error
                print("[YouTubeService] Invidious instance failed: \(instance) - \(error.localizedDescription)")
                continue
            }
        }
        
        throw lastError
    }
    
    // MARK: - Stream URL Extraction
    
    func getStreamURL(videoId: String) async throws -> URL {
        // Check cache first
        if let cached = streamCache[videoId], cached.expires > Date() {
            print("[YouTubeService] Using cached stream URL for \(videoId)")
            return cached.url
        }
        
        // Try Piped first - server-side extraction is much faster than client-side YouTubeKit
        for instance in pipedInstances {
            do {
                let urlString = "\(instance)/streams/\(videoId)"
                guard let url = URL(string: urlString) else { continue }
                
                var request = URLRequest(url: url)
                request.timeoutInterval = 8
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else { continue }
                
                if let streamURL = try parseStreamURL(from: data) {
                    let expires = Date().addingTimeInterval(4 * 60 * 60)
                    streamCache[videoId] = (streamURL, expires)
                    print("[YouTubeService] Stream URL obtained via Piped: \(instance)")
                    return streamURL
                }
            } catch {
                print("[YouTubeService] Piped \(instance) failed: \(error.localizedDescription)")
                continue
            }
        }
        
        // Try Invidious
        for instance in invidiousInstances {
            do {
                let urlString = "\(instance)/api/v1/videos/\(videoId)"
                guard let url = URL(string: urlString) else { continue }
                
                var request = URLRequest(url: url)
                request.timeoutInterval = 8
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else { continue }
                
                if let streamURL = try parseInvidiousStreamURL(from: data) {
                    let expires = Date().addingTimeInterval(4 * 60 * 60)
                    streamCache[videoId] = (streamURL, expires)
                    print("[YouTubeService] Stream URL obtained via Invidious: \(instance)")
                    return streamURL
                }
            } catch {
                print("[YouTubeService] Invidious \(instance) failed: \(error.localizedDescription)")
                continue
            }
        }
        
        // Fallback to YouTubeKit (slower due to client-side signature descrambling)
        print("[YouTubeService] Trying YouTubeKit (this may take a few seconds)...")
        do {
            let video = YouTube(videoID: videoId)
            let streams = try await video.streams
            
            // Get best audio-only stream (M4A preferred for iOS)
            if let audioStream = streams
                .filterAudioOnly()
                .filter({ $0.fileExtension == .m4a })
                .highestAudioBitrateStream() {
                
                let expires = Date().addingTimeInterval(4 * 60 * 60)
                streamCache[videoId] = (audioStream.url, expires)
                print("[YouTubeService] Stream URL obtained via YouTubeKit (m4a audio)")
                return audioStream.url
            }
            
            // Fallback to any audio stream
            if let audioStream = streams.filterAudioOnly().highestAudioBitrateStream() {
                let expires = Date().addingTimeInterval(4 * 60 * 60)
                streamCache[videoId] = (audioStream.url, expires)
                print("[YouTubeService] Stream URL obtained via YouTubeKit (audio)")
                return audioStream.url
            }
            
            // Last resort: video with audio
            if let videoStream = streams
                .filterVideoAndAudio()
                .filter({ $0.isNativelyPlayable })
                .first {
                
                let expires = Date().addingTimeInterval(4 * 60 * 60)
                streamCache[videoId] = (videoStream.url, expires)
                print("[YouTubeService] Stream URL obtained via YouTubeKit (video+audio)")
                return videoStream.url
            }
        } catch {
            print("[YouTubeService] YouTubeKit extraction failed: \(error.localizedDescription)")
        }
        
        throw YouTubeError.streamExtractionFailed
    }
    
    private func parseStreamURL(from data: Data) throws -> URL? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Look for audio streams first (better for music, less bandwidth)
        if let audioStreams = json["audioStreams"] as? [[String: Any]], !audioStreams.isEmpty {
            // Sort by bitrate, prefer highest quality
            let sorted = audioStreams.sorted { a, b in
                (a["bitrate"] as? Int ?? 0) > (b["bitrate"] as? Int ?? 0)
            }
            
            // Prefer M4A/AAC format for better iOS compatibility
            for stream in sorted {
                if let mimeType = stream["mimeType"] as? String,
                   (mimeType.contains("mp4") || mimeType.contains("m4a") || mimeType.contains("aac")),
                   let urlString = stream["url"] as? String,
                   let url = URL(string: urlString) {
                    print("[YouTubeService] Selected audio stream: \(mimeType), bitrate: \(stream["bitrate"] ?? "?")")
                    return url
                }
            }
            
            // Fallback to any audio stream
            for stream in sorted {
                if let urlString = stream["url"] as? String,
                   let url = URL(string: urlString) {
                    print("[YouTubeService] Selected fallback audio stream")
                    return url
                }
            }
        }
        
        // Fallback to HLS stream (adaptive streaming)
        if let hlsString = json["hls"] as? String,
           let hlsURL = URL(string: hlsString) {
            print("[YouTubeService] Using HLS stream")
            return hlsURL
        }
        
        // Last resort: try video streams with audio
        if let videoStreams = json["videoStreams"] as? [[String: Any]] {
            for stream in videoStreams {
                if let hasAudio = stream["videoOnly"] as? Bool, !hasAudio,
                   let urlString = stream["url"] as? String,
                   let url = URL(string: urlString) {
                    print("[YouTubeService] Using video stream with audio")
                    return url
                }
            }
        }
        
        return nil
    }
    
    private func parseInvidiousStreamURL(from data: Data) throws -> URL? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Invidious uses "adaptiveFormats" for audio/video streams
        if let adaptiveFormats = json["adaptiveFormats"] as? [[String: Any]] {
            // Filter for audio-only streams
            let audioStreams = adaptiveFormats.filter { format in
                if let type = format["type"] as? String {
                    return type.hasPrefix("audio/")
                }
                return false
            }
            
            // Sort by bitrate
            let sorted = audioStreams.sorted { a, b in
                let bitrateA = (a["bitrate"] as? String).flatMap { Int($0) } ?? 0
                let bitrateB = (b["bitrate"] as? String).flatMap { Int($0) } ?? 0
                return bitrateA > bitrateB
            }
            
            // Prefer M4A/AAC for iOS compatibility
            for stream in sorted {
                if let type = stream["type"] as? String,
                   (type.contains("mp4") || type.contains("m4a")),
                   let urlString = stream["url"] as? String,
                   let url = URL(string: urlString) {
                    print("[YouTubeService] Invidious: Selected audio \(type)")
                    return url
                }
            }
            
            // Fallback to any audio
            for stream in sorted {
                if let urlString = stream["url"] as? String,
                   let url = URL(string: urlString) {
                    return url
                }
            }
        }
        
        // Fallback to format streams (lower quality but compatible)
        if let formatStreams = json["formatStreams"] as? [[String: Any]] {
            for stream in formatStreams {
                if let urlString = stream["url"] as? String,
                   let url = URL(string: urlString) {
                    print("[YouTubeService] Invidious: Using format stream")
                    return url
                }
            }
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
    case networkError(String)
    case noResults
    case apiKeyRequired
    case apiKeyInvalid
    
    var errorDescription: String? {
        switch self {
        case .searchFailed:
            return "Unable to search right now. Check your internet connection and try again."
        case .streamExtractionFailed:
            return "Unable to load this track. The stream may be unavailable. Try another track."
        case .invalidVideoId:
            return "Invalid video ID."
        case .networkError(let message):
            return "Network error: \(message)"
        case .noResults:
            return "No results found. Try a different search."
        case .apiKeyRequired:
            return "YouTube API key required. Add your API key in Settings to enable search."
        case .apiKeyInvalid:
            return "Invalid YouTube API key. Please check your API key in Settings."
        }
    }
}

import Foundation

// Represents a single line of lyrics with timing
struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: Double // in seconds
    let text: String
    
    static func == (lhs: LyricLine, rhs: LyricLine) -> Bool {
        lhs.id == rhs.id
    }
}

final class LyricsService: ObservableObject {
    static let shared = LyricsService()
    
    @Published var currentLyrics: String?
    @Published var syncedLyrics: [LyricLine] = []
    @Published var hasSyncedLyrics = false
    @Published var isLoading = false
    @Published var error: String?
    
    private var currentTrackTitle: String?
    private var currentArtist: String?
    private var cache: [String: String] = [:]
    private var syncedCache: [String: [LyricLine]] = [:]
    
    private init() {}
    
    func fetchLyrics(for title: String, artist: String?) async {
        let cacheKey = "\(title)-\(artist ?? "")"
        
        // Check cache first
        if let cached = cache[cacheKey] {
            let syncedCached = syncedCache[cacheKey] ?? []
            await MainActor.run {
                self.currentLyrics = cached
                self.syncedLyrics = syncedCached
                self.hasSyncedLyrics = !syncedCached.isEmpty
                self.isLoading = false
                self.error = nil
            }
            return
        }
        
        // Skip if same track
        if title == currentTrackTitle && artist == currentArtist && currentLyrics != nil {
            return
        }
        
        currentTrackTitle = title
        currentArtist = artist
        
        await MainActor.run {
            self.isLoading = true
            self.error = nil
            self.currentLyrics = nil
            self.syncedLyrics = []
            self.hasSyncedLyrics = false
        }
        
        let cleanedTitle = cleanTitle(title)
        let searchArtist = artist ?? "Unknown"
        
        // Try LRCLIB first (better coverage, supports synced lyrics)
        if let result = await fetchFromLrclib(title: title, artist: searchArtist) {
            cache[cacheKey] = result.plain
            if !result.synced.isEmpty {
                syncedCache[cacheKey] = result.synced
            }
            await MainActor.run {
                self.currentLyrics = result.plain
                self.syncedLyrics = result.synced
                self.hasSyncedLyrics = !result.synced.isEmpty
                self.isLoading = false
            }
            return
        }
        
        // Try with cleaned title
        if cleanedTitle != title {
            if let result = await fetchFromLrclib(title: cleanedTitle, artist: searchArtist) {
                cache[cacheKey] = result.plain
                if !result.synced.isEmpty {
                    syncedCache[cacheKey] = result.synced
                }
                await MainActor.run {
                    self.currentLyrics = result.plain
                    self.syncedLyrics = result.synced
                    self.hasSyncedLyrics = !result.synced.isEmpty
                    self.isLoading = false
                }
                return
            }
        }
        
        // Fallback to lyrics.ovh (no synced lyrics)
        if let lyrics = await fetchFromLyricsOvh(title: title, artist: searchArtist) {
            cache[cacheKey] = lyrics
            await MainActor.run {
                self.currentLyrics = lyrics
                self.syncedLyrics = []
                self.hasSyncedLyrics = false
                self.isLoading = false
            }
            return
        }
        
        // Try lyrics.ovh with cleaned title
        if cleanedTitle != title {
            if let lyrics = await fetchFromLyricsOvh(title: cleanedTitle, artist: searchArtist) {
                cache[cacheKey] = lyrics
                await MainActor.run {
                    self.currentLyrics = lyrics
                    self.syncedLyrics = []
                    self.hasSyncedLyrics = false
                    self.isLoading = false
                }
                return
            }
        }
        
        await MainActor.run {
            self.isLoading = false
            self.error = "Lyrics not found"
        }
    }
    
    // Result struct for LRCLIB fetch
    private struct LrclibFetchResult {
        let plain: String
        let synced: [LyricLine]
    }
    
    private func fetchFromLrclib(title: String, artist: String) async -> LrclibFetchResult? {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        
        guard let url = components?.url else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Vibic/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let result = try JSONDecoder().decode(LrclibResponse.self, from: data)
            
            // Parse synced lyrics if available
            var syncedLines: [LyricLine] = []
            if let syncedLyrics = result.syncedLyrics, !syncedLyrics.isEmpty {
                syncedLines = parseSyncedLyrics(syncedLyrics)
            }
            
            // Get plain lyrics (or strip from synced)
            let plainLyrics: String
            if let plain = result.plainLyrics, !plain.isEmpty {
                plainLyrics = cleanLyrics(plain)
            } else if let synced = result.syncedLyrics, !synced.isEmpty {
                plainLyrics = cleanLyrics(stripTimestamps(synced))
            } else {
                return nil
            }
            
            return LrclibFetchResult(plain: plainLyrics, synced: syncedLines)
        } catch {
            print("LRCLIB fetch error: \(error)")
            return nil
        }
    }
    
    // Parse LRC format timestamps into LyricLine objects
    private func parseSyncedLyrics(_ syncedLyrics: String) -> [LyricLine] {
        let lines = syncedLyrics.components(separatedBy: "\n")
        var result: [LyricLine] = []
        
        // Regex to match [mm:ss.xx] format
        let pattern = "^\\[(\\d{2}):(\\d{2})\\.(\\d{2})\\]\\s*(.*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, options: [], range: range) {
                // Extract time components
                if let minutesRange = Range(match.range(at: 1), in: line),
                   let secondsRange = Range(match.range(at: 2), in: line),
                   let centisecondsRange = Range(match.range(at: 3), in: line),
                   let textRange = Range(match.range(at: 4), in: line) {
                    
                    let minutes = Double(line[minutesRange]) ?? 0
                    let seconds = Double(line[secondsRange]) ?? 0
                    let centiseconds = Double(line[centisecondsRange]) ?? 0
                    
                    let time = minutes * 60 + seconds + centiseconds / 100
                    let text = String(line[textRange]).trimmingCharacters(in: .whitespaces)
                    
                    if !text.isEmpty {
                        result.append(LyricLine(time: time, text: text))
                    }
                }
            }
        }
        
        return result.sorted { $0.time < $1.time }
    }
    
    private func fetchFromLyricsOvh(title: String, artist: String) async -> String? {
        let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? artist
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        
        let urlString = "https://api.lyrics.ovh/v1/\(encodedArtist)/\(encodedTitle)"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let result = try JSONDecoder().decode(LyricsResponse.self, from: data)
            return cleanLyrics(result.lyrics)
        } catch {
            print("Lyrics.ovh fetch error: \(error)")
            return nil
        }
    }
    
    private func stripTimestamps(_ syncedLyrics: String) -> String {
        let lines = syncedLyrics.components(separatedBy: "\n")
        var result: [String] = []
        
        for line in lines {
            // Remove [mm:ss.xx] timestamps
            if let regex = try? NSRegularExpression(pattern: "^\\[\\d{2}:\\d{2}\\.\\d{2}\\]\\s*", options: []) {
                let range = NSRange(line.startIndex..., in: line)
                let cleaned = regex.stringByReplacingMatches(in: line, options: [], range: range, withTemplate: "")
                if !cleaned.isEmpty {
                    result.append(cleaned)
                }
            } else {
                result.append(line)
            }
        }
        
        return result.joined(separator: "\n")
    }
    
    private func cleanTitle(_ title: String) -> String {
        var cleaned = title
        
        // Remove common suffixes in parentheses or brackets
        let patterns = [
            "\\s*\\(.*\\)\\s*$",
            "\\s*\\[.*\\]\\s*$",
            "\\s*-\\s*Remaster.*$",
            "\\s*-\\s*\\d{4}.*$",
            "\\s*feat\\..*$",
            "\\s*ft\\..*$"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(cleaned.startIndex..., in: cleaned)
                cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    private func cleanLyrics(_ lyrics: String) -> String {
        var cleaned = lyrics
        
        // Remove excessive newlines
        while cleaned.contains("\n\n\n") {
            cleaned = cleaned.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    func clearLyrics() {
        currentLyrics = nil
        syncedLyrics = []
        hasSyncedLyrics = false
        currentTrackTitle = nil
        currentArtist = nil
        error = nil
    }
    
    // Get the current lyric line index based on playback time
    func getCurrentLineIndex(at time: Double) -> Int? {
        guard !syncedLyrics.isEmpty else { return nil }
        
        // Find the last line that has started
        var currentIndex: Int? = nil
        for (index, line) in syncedLyrics.enumerated() {
            if line.time <= time {
                currentIndex = index
            } else {
                break
            }
        }
        return currentIndex
    }
}

struct LyricsResponse: Codable {
    let lyrics: String
}

struct LrclibResponse: Codable {
    let plainLyrics: String?
    let syncedLyrics: String?
}

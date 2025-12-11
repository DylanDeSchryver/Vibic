import Foundation

final class LyricsService: ObservableObject {
    static let shared = LyricsService()
    
    @Published var currentLyrics: String?
    @Published var isLoading = false
    @Published var error: String?
    
    private var currentTrackTitle: String?
    private var currentArtist: String?
    private var cache: [String: String] = [:]
    
    private init() {}
    
    func fetchLyrics(for title: String, artist: String?) async {
        let cacheKey = "\(title)-\(artist ?? "")"
        
        // Check cache first
        if let cached = cache[cacheKey] {
            await MainActor.run {
                self.currentLyrics = cached
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
        }
        
        let cleanedTitle = cleanTitle(title)
        let searchArtist = artist ?? "Unknown"
        
        // Try LRCLIB first (better coverage)
        if let lyrics = await fetchFromLrclib(title: title, artist: searchArtist) {
            cache[cacheKey] = lyrics
            await MainActor.run {
                self.currentLyrics = lyrics
                self.isLoading = false
            }
            return
        }
        
        // Try with cleaned title
        if cleanedTitle != title {
            if let lyrics = await fetchFromLrclib(title: cleanedTitle, artist: searchArtist) {
                cache[cacheKey] = lyrics
                await MainActor.run {
                    self.currentLyrics = lyrics
                    self.isLoading = false
                }
                return
            }
        }
        
        // Fallback to lyrics.ovh
        if let lyrics = await fetchFromLyricsOvh(title: title, artist: searchArtist) {
            cache[cacheKey] = lyrics
            await MainActor.run {
                self.currentLyrics = lyrics
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
    
    private func fetchFromLrclib(title: String, artist: String) async -> String? {
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
            // Prefer plain lyrics, fall back to synced lyrics stripped of timestamps
            if let plainLyrics = result.plainLyrics, !plainLyrics.isEmpty {
                return cleanLyrics(plainLyrics)
            } else if let syncedLyrics = result.syncedLyrics, !syncedLyrics.isEmpty {
                return cleanLyrics(stripTimestamps(syncedLyrics))
            }
            return nil
        } catch {
            print("LRCLIB fetch error: \(error)")
            return nil
        }
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
        currentTrackTitle = nil
        currentArtist = nil
        error = nil
    }
}

struct LyricsResponse: Codable {
    let lyrics: String
}

struct LrclibResponse: Codable {
    let plainLyrics: String?
    let syncedLyrics: String?
}

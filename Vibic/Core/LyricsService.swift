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
        
        // Try multiple sources
        if let lyrics = await fetchFromLyricsOvh(title: title, artist: artist ?? "Unknown") {
            cache[cacheKey] = lyrics
            await MainActor.run {
                self.currentLyrics = lyrics
                self.isLoading = false
            }
            return
        }
        
        // Try alternate search with cleaned title
        let cleanedTitle = cleanTitle(title)
        if cleanedTitle != title {
            if let lyrics = await fetchFromLyricsOvh(title: cleanedTitle, artist: artist ?? "Unknown") {
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
            print("Lyrics fetch error: \(error)")
            return nil
        }
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

import Foundation
import UIKit

struct NowPlayingData: Codable {
    var trackTitle: String
    var artistName: String?
    var isPlaying: Bool
    var currentTime: Double
    var duration: Double
    var artworkData: Data?
    var trackId: String?
    
    static let empty = NowPlayingData(
        trackTitle: "Not Playing",
        artistName: nil,
        isPlaying: false,
        currentTime: 0,
        duration: 0,
        artworkData: nil,
        trackId: nil
    )
}

class NowPlayingShared {
    static let shared = NowPlayingShared()
    
    private let appGroupId = "group.com.vibic.app"
    private let nowPlayingKey = "nowPlayingData"
    
    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }
    
    private init() {}
    
    func save(_ data: NowPlayingData) {
        guard let userDefaults = userDefaults else { return }
        
        if let encoded = try? JSONEncoder().encode(data) {
            userDefaults.set(encoded, forKey: nowPlayingKey)
        }
    }
    
    func load() -> NowPlayingData {
        guard let userDefaults = userDefaults,
              let data = userDefaults.data(forKey: nowPlayingKey),
              let decoded = try? JSONDecoder().decode(NowPlayingData.self, from: data) else {
            return .empty
        }
        return decoded
    }
    
    func clear() {
        userDefaults?.removeObject(forKey: nowPlayingKey)
    }
}

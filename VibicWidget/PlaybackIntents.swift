//
//  PlaybackIntents.swift
//  VibicWidget
//
//  Created by Dylan De Schryver on 12/11/25.
//

import AppIntents
import WidgetKit

struct PlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Play/Pause"
    static var description = IntentDescription("Toggle play/pause")
    
    func perform() async throws -> some IntentResult {
        // Send notification to main app
        let defaults = UserDefaults(suiteName: "group.com.vibic.app")
        defaults?.set("togglePlayPause", forKey: "widgetAction")
        defaults?.set(Date(), forKey: "widgetActionTimestamp")
        
        WidgetCenter.shared.reloadTimelines(ofKind: "VibicNowPlaying")
        return .result()
    }
}

struct NextTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Track"
    static var description = IntentDescription("Skip to next track")
    
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.vibic.app")
        defaults?.set("nextTrack", forKey: "widgetAction")
        defaults?.set(Date(), forKey: "widgetActionTimestamp")
        
        WidgetCenter.shared.reloadTimelines(ofKind: "VibicNowPlaying")
        return .result()
    }
}

struct PreviousTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Track"
    static var description = IntentDescription("Skip to previous track")
    
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.vibic.app")
        defaults?.set("previousTrack", forKey: "widgetAction")
        defaults?.set(Date(), forKey: "widgetActionTimestamp")
        
        WidgetCenter.shared.reloadTimelines(ofKind: "VibicNowPlaying")
        return .result()
    }
}

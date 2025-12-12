//
//  VibicWidget.swift
//  VibicWidget
//
//  Created by Dylan De Schryver on 12/11/25.
//

import WidgetKit
import SwiftUI
import AppIntents

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let data: NowPlayingData
}

struct NowPlayingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(date: Date(), data: .empty)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        let data = NowPlayingShared.shared.load()
        completion(NowPlayingEntry(date: Date(), data: data))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        let data = NowPlayingShared.shared.load()
        let entry = NowPlayingEntry(date: Date(), data: data)
        
        // Refresh every 30 seconds when playing, every 5 minutes when not
        let refreshInterval: TimeInterval = data.isPlaying ? 30 : 300
        let nextUpdate = Date().addingTimeInterval(refreshInterval)
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct NowPlayingWidgetEntryView: View {
    var entry: NowPlayingEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: entry.data)
        case .systemMedium:
            MediumWidgetView(data: entry.data)
        default:
            SmallWidgetView(data: entry.data)
        }
    }
}

struct SmallWidgetView: View {
    let data: NowPlayingData
    
    var body: some View {
        VStack(spacing: 8) {
            // Artwork - larger size
            if let artworkData = data.artworkData,
               let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
            }
            
            // Track info
            VStack(spacing: 2) {
                Text(data.trackTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                if let artist = data.artistName {
                    Text(artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            // Playback controls
            HStack(spacing: 20) {
                Button(intent: PreviousTrackIntent()) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                
                Button(intent: PlayPauseIntent()) {
                    Image(systemName: data.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                
                Button(intent: NextTrackIntent()) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

struct MediumWidgetView: View {
    let data: NowPlayingData
    
    var progressPercent: CGFloat {
        guard data.duration > 0 else { return 0 }
        return CGFloat(min(max(data.currentTime / data.duration, 0), 1.0))
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Artwork - slightly larger
            if let artworkData = data.artworkData,
               let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.2))
                    .frame(width: 90, height: 90)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.trackTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    if let artist = data.artistName {
                        Text(artist)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                
                // Progress bar
                VStack(spacing: 2) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.3))
                            .frame(height: 4)
                        
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white)
                                .frame(width: geo.size.width * progressPercent, height: 4)
                        }
                        .frame(height: 4)
                    }
                    
                    // Time labels
                    HStack {
                        Text(formatTime(data.currentTime))
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Text(formatTime(data.duration))
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                
                // Playback controls
                HStack(spacing: 24) {
                    Button(intent: PreviousTrackIntent()) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(intent: PlayPauseIntent()) {
                        Image(systemName: data.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(intent: NextTrackIntent()) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }
    
    func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ProgressBarView: View {
    let progress: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.3))
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white)
                    .frame(width: max(0, geometry.size.width * progress))
            }
        }
    }
}

struct VibicWidget: Widget {
    let kind: String = "VibicNowPlaying"
    
    static let gradient = LinearGradient(
        colors: [Color(red: 0.545, green: 0.361, blue: 0.965),
                 Color(red: 0.925, green: 0.286, blue: 0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NowPlayingProvider()) { entry in
            NowPlayingWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    VibicWidget.gradient
                }
        }
        .configurationDisplayName("Now Playing")
        .description("Shows the currently playing track in Vibic.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    VibicWidget()
} timeline: {
    NowPlayingEntry(date: .now, data: NowPlayingData(
        trackTitle: "Sample Song",
        artistName: "Artist Name",
        isPlaying: true,
        currentTime: 45,
        duration: 180,
        artworkData: nil,
        trackId: nil
    ))
}

#Preview(as: .systemMedium) {
    VibicWidget()
} timeline: {
    NowPlayingEntry(date: .now, data: NowPlayingData(
        trackTitle: "Sample Song Title",
        artistName: "Artist Name",
        isPlaying: true,
        currentTime: 45,
        duration: 180,
        artworkData: nil,
        trackId: nil
    ))
}

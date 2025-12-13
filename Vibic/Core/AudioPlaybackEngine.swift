import Foundation
import AVFoundation
import MediaPlayer
import Combine
import WidgetKit

final class AudioPlaybackEngine: NSObject, ObservableObject {
    static let shared = AudioPlaybackEngine()
    
    private var audioPlayer: AVAudioPlayer?
    private var streamPlayer: AVPlayer?
    private var streamPlayerObserver: Any?
    private var isStreamingTrack = false
    private var displayLink: CADisplayLink?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    
    @Published var currentTrack: Track?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Float = 1.0
    
    // MARK: - Queue Management
    
    @Published var queue: [Track] = []
    @Published var currentIndex: Int = 0
    @Published var shuffleEnabled = false
    @Published var repeatMode: RepeatMode = .none
    
    private var originalQueue: [Track] = []
    
    enum RepeatMode {
        case none
        case all
        case one
    }
    
    // MARK: - Playback Settings
    
    var gaplessPlayback = true
    var crossfadeEnabled = false
    var crossfadeDuration: Double = 3.0
    private var crossfadeTimer: Timer?
    private var nextAudioPlayer: AVAudioPlayer?
    private var isCrossfading = false
    private var crossfadeStartTime: Date?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupRemoteCommandCenter()
        setupAudioSession()
        loadSettingsFromDefaults()
        setupWidgetActionObserver()
    }
    
    private func setupWidgetActionObserver() {
        // Check for widget actions periodically
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkWidgetAction()
        }
    }
    
    private func checkWidgetAction() {
        guard let defaults = UserDefaults(suiteName: "group.com.vibic.app"),
              let action = defaults.string(forKey: "widgetAction"),
              let timestamp = defaults.object(forKey: "widgetActionTimestamp") as? Date else {
            return
        }
        
        // Only process recent actions (within last 2 seconds)
        guard Date().timeIntervalSince(timestamp) < 2 else { return }
        
        // Clear the action
        defaults.removeObject(forKey: "widgetAction")
        defaults.removeObject(forKey: "widgetActionTimestamp")
        
        DispatchQueue.main.async { [weak self] in
            switch action {
            case "togglePlayPause":
                self?.togglePlayPause()
            case "nextTrack":
                self?.playNext()
            case "previousTrack":
                self?.playPrevious()
            default:
                break
            }
        }
    }
    
    deinit {
        stopDisplayLink()
    }
    
    // MARK: - Audio Session
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Playback Control
    
    func loadTrack(_ track: Track) {
        // Handle streamed tracks
        if track.isStreamedTrack, let videoId = track.videoId {
            loadStreamedTrack(track, videoId: videoId)
            return
        }
        
        // Handle local tracks
        guard let filePath = track.filePath else { return }
        let fileURL = URL(fileURLWithPath: filePath)
        
        do {
            stopAllPlayers()
            isStreamingTrack = false
            
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = volume
            
            currentTrack = track
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
            
            updateNowPlayingInfo()
        } catch {
            print("Failed to load audio: \(error)")
        }
    }
    
    private func loadStreamedTrack(_ track: Track, videoId: String) {
        stopAllPlayers()
        isStreamingTrack = true
        currentTrack = track
        duration = track.duration
        currentTime = 0
        
        // Show loading state
        updateNowPlayingInfo()
        
        Task {
            do {
                let streamURL = try await YouTubeService.shared.getStreamURL(videoId: videoId)
                
                await MainActor.run {
                    let playerItem = AVPlayerItem(url: streamURL)
                    
                    // Configure for audio streaming
                    playerItem.preferredForwardBufferDuration = 10
                    
                    streamPlayer = AVPlayer(playerItem: playerItem)
                    streamPlayer?.volume = volume
                    streamPlayer?.automaticallyWaitsToMinimizeStalling = true
                    
                    // Observe player item status for errors
                    streamPlayerObserver = playerItem.observe(\.status) { [weak self] item, _ in
                        DispatchQueue.main.async {
                            switch item.status {
                            case .readyToPlay:
                                if let duration = self?.streamPlayer?.currentItem?.duration,
                                   duration.isNumeric {
                                    self?.duration = CMTimeGetSeconds(duration)
                                }
                            case .failed:
                                print("[AudioPlaybackEngine] Stream playback failed: \(item.error?.localizedDescription ?? "Unknown error")")
                                // Try next track if there's a queue
                                if self?.queue.count ?? 0 > 1 {
                                    self?.playNext()
                                }
                            default:
                                break
                            }
                        }
                    }
                    
                    // Observe when playback ends
                    NotificationCenter.default.addObserver(
                        self,
                        selector: #selector(streamPlayerDidFinishPlaying),
                        name: .AVPlayerItemDidPlayToEndTime,
                        object: playerItem
                    )
                    
                    // Observe for playback stalls
                    NotificationCenter.default.addObserver(
                        self,
                        selector: #selector(streamPlayerStalled),
                        name: .AVPlayerItemPlaybackStalled,
                        object: playerItem
                    )
                    
                    // Auto-play
                    play()
                }
            } catch {
                print("[AudioPlaybackEngine] Failed to load stream: \(error)")
                await MainActor.run {
                    // Only try next track if there's a queue with more items
                    if queue.count > 1 {
                        playNext()
                    } else {
                        // Reset state if single track failed
                        isPlaying = false
                        stopDisplayLink()
                    }
                }
            }
        }
    }
    
    @objc private func streamPlayerStalled(_ notification: Notification) {
        print("[AudioPlaybackEngine] Stream playback stalled, attempting to resume...")
        // AVPlayer should automatically resume when buffer is ready
    }
    
    @objc private func streamPlayerDidFinishPlaying(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.playNext()
        }
    }
    
    private func stopAllPlayers() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        streamPlayer?.pause()
        if let observer = streamPlayerObserver {
            (observer as? NSKeyValueObservation)?.invalidate()
        }
        streamPlayerObserver = nil
        streamPlayer = nil
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemPlaybackStalled, object: nil)
    }
    
    func play() {
        if isStreamingTrack {
            streamPlayer?.play()
        } else {
            audioPlayer?.play()
        }
        isPlaying = true
        startDisplayLink()
        updateNowPlayingInfo()
    }
    
    func pause() {
        if isStreamingTrack {
            streamPlayer?.pause()
        } else {
            audioPlayer?.pause()
        }
        isPlaying = false
        stopDisplayLink()
        updateNowPlayingInfo()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func stop() {
        cancelCrossfade()
        stopAllPlayers()
        isStreamingTrack = false
        isPlaying = false
        currentTime = 0
        stopDisplayLink()
        clearNowPlayingInfo()
    }
    
    func seek(to time: Double) {
        if isStreamingTrack {
            let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
            streamPlayer?.seek(to: cmTime)
        } else {
            audioPlayer?.currentTime = time
        }
        currentTime = time
        updateNowPlayingInfo()
    }
    
    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        audioPlayer?.volume = volume
        streamPlayer?.volume = volume
    }
    
    // MARK: - Queue Management
    
    func playTrack(_ track: Track, in tracks: [Track]) {
        originalQueue = tracks
        
        if shuffleEnabled {
            var shuffled = tracks.shuffled()
            if let index = shuffled.firstIndex(where: { $0.id == track.id }) {
                shuffled.remove(at: index)
                shuffled.insert(track, at: 0)
            }
            queue = shuffled
            currentIndex = 0
        } else {
            queue = tracks
            currentIndex = tracks.firstIndex(where: { $0.id == track.id }) ?? 0
        }
        
        loadTrack(track)
        play()
    }
    
    func playTrack(_ track: Track) {
        playTrack(track, in: [track])
    }
    
    func playNext() {
        guard !queue.isEmpty else { return }
        cancelCrossfade()
        
        if repeatMode == .one {
            seek(to: 0)
            play()
            return
        }
        
        let nextIndex = currentIndex + 1
        
        if nextIndex >= queue.count {
            if repeatMode == .all {
                currentIndex = 0
                loadTrack(queue[0])
                play()
            } else {
                stop()
                currentTrack = nil
            }
        } else {
            currentIndex = nextIndex
            loadTrack(queue[nextIndex])
            play()
        }
    }
    
    func playPrevious() {
        guard !queue.isEmpty else { return }
        cancelCrossfade()
        
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        
        let previousIndex = currentIndex - 1
        
        if previousIndex < 0 {
            if repeatMode == .all {
                currentIndex = queue.count - 1
                loadTrack(queue[currentIndex])
                play()
            } else {
                seek(to: 0)
            }
        } else {
            currentIndex = previousIndex
            loadTrack(queue[previousIndex])
            play()
        }
    }
    
    func toggleShuffle() {
        shuffleEnabled.toggle()
        
        if shuffleEnabled {
            guard let currentTrack = currentTrack else { return }
            var shuffled = originalQueue.shuffled()
            if let index = shuffled.firstIndex(where: { $0.id == currentTrack.id }) {
                shuffled.remove(at: index)
                shuffled.insert(currentTrack, at: 0)
            }
            queue = shuffled
            currentIndex = 0
        } else {
            if let currentTrack = currentTrack,
               let index = originalQueue.firstIndex(where: { $0.id == currentTrack.id }) {
                currentIndex = index
            }
            queue = originalQueue
        }
    }
    
    func cycleRepeatMode() {
        switch repeatMode {
        case .none:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .none
        }
    }
    
    func setDefaultRepeatMode(_ mode: Int) {
        switch mode {
        case 1:
            repeatMode = .all
        case 2:
            repeatMode = .one
        default:
            repeatMode = .none
        }
    }
    
    func loadSettingsFromDefaults() {
        let defaults = UserDefaults.standard
        gaplessPlayback = defaults.bool(forKey: "gaplessPlayback")
        crossfadeEnabled = defaults.bool(forKey: "crossfadeEnabled")
        crossfadeDuration = defaults.double(forKey: "crossfadeDuration")
        if crossfadeDuration == 0 { crossfadeDuration = 3.0 }
        setDefaultRepeatMode(defaults.integer(forKey: "defaultRepeatMode"))
    }
    
    func addToQueue(_ track: Track) {
        queue.append(track)
        originalQueue.append(track)
    }
    
    func removeFromQueue(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        let removedTrack = queue.remove(at: index)
        originalQueue.removeAll { $0.id == removedTrack.id }
        
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex {
            if queue.isEmpty {
                stop()
                currentTrack = nil
            } else {
                currentIndex = min(currentIndex, queue.count - 1)
                loadTrack(queue[currentIndex])
                play()
            }
        }
    }
    
    func clearQueue() {
        queue.removeAll()
        originalQueue.removeAll()
        currentIndex = 0
    }
    
    // MARK: - Queue Manipulation
    
    /// Move a track to play immediately after the current track
    func moveToPlayNext(from index: Int) {
        guard index > currentIndex && index < queue.count else { return }
        
        let track = queue.remove(at: index)
        let insertIndex = currentIndex + 1
        queue.insert(track, at: insertIndex)
        
        // Update original queue as well
        if let originalIndex = originalQueue.firstIndex(where: { $0.id == track.id }) {
            originalQueue.remove(at: originalIndex)
            let originalInsertIndex = min(currentIndex + 1, originalQueue.count)
            originalQueue.insert(track, at: originalInsertIndex)
        }
    }
    
    /// Move a track from one position to another in the queue
    func moveTrack(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < queue.count,
              destinationIndex >= 0, destinationIndex < queue.count else { return }
        
        let track = queue.remove(at: sourceIndex)
        queue.insert(track, at: destinationIndex)
        
        // Adjust currentIndex if needed
        if sourceIndex == currentIndex {
            currentIndex = destinationIndex
        } else if sourceIndex < currentIndex && destinationIndex >= currentIndex {
            currentIndex -= 1
        } else if sourceIndex > currentIndex && destinationIndex <= currentIndex {
            currentIndex += 1
        }
        
        // Update original queue
        if let originalSourceIndex = originalQueue.firstIndex(where: { $0.id == track.id }) {
            originalQueue.remove(at: originalSourceIndex)
            let clampedDestination = min(destinationIndex, originalQueue.count)
            originalQueue.insert(track, at: clampedDestination)
        }
    }
    
    /// Get upcoming tracks (tracks after current)
    var upcomingTracks: [Track] {
        guard currentIndex + 1 < queue.count else { return [] }
        return Array(queue[(currentIndex + 1)...])
    }
    
    /// Get history tracks (tracks before current)
    var historyTracks: [Track] {
        guard currentIndex > 0 else { return [] }
        return Array(queue[0..<currentIndex])
    }
    
    // MARK: - Display Link for Time Updates
    
    private func startDisplayLink() {
        stopDisplayLink()
        displayLink = CADisplayLink(target: self, selector: #selector(updatePlaybackTime))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 30)
        // Use .default mode so updates pause during scrolling for smoother performance
        displayLink?.add(to: .main, forMode: .default)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updatePlaybackTime() {
        let newTime: Double
        
        if isStreamingTrack {
            guard let player = streamPlayer else { return }
            newTime = CMTimeGetSeconds(player.currentTime())
            guard !newTime.isNaN && !newTime.isInfinite else { return }
        } else {
            guard let player = audioPlayer else { return }
            newTime = player.currentTime
        }
        
        // Only update if time changed by more than 0.25s to reduce re-renders
        // PlayerView can interpolate for smooth progress bar
        if abs(newTime - currentTime) >= 0.25 {
            currentTime = newTime
        }
        
        // Check for crossfade (local tracks only)
        if !isStreamingTrack && crossfadeEnabled && !isCrossfading && duration > 0 {
            let timeRemaining = duration - newTime
            if timeRemaining <= crossfadeDuration && timeRemaining > 0 {
                startCrossfade()
            }
        }
        
        // Update crossfade volumes
        if isCrossfading, let startTime = crossfadeStartTime {
            updateCrossfadeVolumes(startTime: startTime)
        }
    }
    
    // MARK: - Crossfade
    
    private func startCrossfade() {
        guard !isCrossfading else { return }
        guard let nextTrack = getNextTrackForCrossfade() else { return }
        guard let filePath = nextTrack.filePath else { return }
        
        let fileURL = URL(fileURLWithPath: filePath)
        
        do {
            nextAudioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            nextAudioPlayer?.prepareToPlay()
            nextAudioPlayer?.volume = 0
            nextAudioPlayer?.play()
            
            isCrossfading = true
            crossfadeStartTime = Date()
        } catch {
            print("Failed to prepare next track for crossfade: \(error)")
        }
    }
    
    private func getNextTrackForCrossfade() -> Track? {
        guard !queue.isEmpty else { return nil }
        
        if repeatMode == .one {
            return currentTrack
        }
        
        let nextIndex = currentIndex + 1
        if nextIndex >= queue.count {
            if repeatMode == .all {
                return queue[0]
            }
            return nil
        }
        return queue[nextIndex]
    }
    
    private func updateCrossfadeVolumes(startTime: Date) {
        let elapsed = Date().timeIntervalSince(startTime)
        let progress = min(elapsed / crossfadeDuration, 1.0)
        
        // Fade out current, fade in next
        audioPlayer?.volume = Float(1.0 - progress) * volume
        nextAudioPlayer?.volume = Float(progress) * volume
        
        // Crossfade complete
        if progress >= 1.0 {
            completeCrossfade()
        }
    }
    
    private func completeCrossfade() {
        audioPlayer?.stop()
        audioPlayer = nextAudioPlayer
        audioPlayer?.volume = volume
        nextAudioPlayer = nil
        isCrossfading = false
        crossfadeStartTime = nil
        
        // Update track info
        if repeatMode == .one {
            // Stay on same track, just restart
            currentTime = 0
        } else {
            let nextIndex = currentIndex + 1
            if nextIndex >= queue.count {
                if repeatMode == .all {
                    currentIndex = 0
                }
            } else {
                currentIndex = nextIndex
            }
            currentTrack = queue[currentIndex]
        }
        
        duration = audioPlayer?.duration ?? 0
        updateNowPlayingInfo()
    }
    
    private func cancelCrossfade() {
        nextAudioPlayer?.stop()
        nextAudioPlayer = nil
        isCrossfading = false
        crossfadeStartTime = nil
        audioPlayer?.volume = volume
    }
    
    // MARK: - Remote Command Center
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seek(to: positionEvent.positionTime)
            return .success
        }
    }
    
    // MARK: - Now Playing Info
    
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        
        if let track = currentTrack {
            nowPlayingInfo[MPMediaItemPropertyTitle] = track.title ?? "Unknown"
            nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist ?? "Unknown Artist"
            
            // Add artwork for lock screen, control center, and Dynamic Island
            if let artworkImage = track.artworkImage {
                let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in
                    return artworkImage
                }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }
        }
        
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        // Sync with widget
        updateWidgetData()
    }
    
    private func updateWidgetData() {
        guard let track = currentTrack else {
            NowPlayingShared.shared.clear()
            WidgetCenter.shared.reloadTimelines(ofKind: "VibicNowPlaying")
            return
        }
        
        let data = NowPlayingData(
            trackTitle: track.title ?? "Unknown",
            artistName: track.artist,
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: duration,
            artworkData: track.artworkData,
            trackId: track.id?.uuidString
        )
        
        NowPlayingShared.shared.save(data)
        WidgetCenter.shared.reloadTimelines(ofKind: "VibicNowPlaying")
    }
    
    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        NowPlayingShared.shared.clear()
    }
    
    // MARK: - Utility
    
    func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlaybackEngine: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // If crossfade handled the transition, don't trigger playNext
        if isCrossfading || player === nextAudioPlayer {
            return
        }
        
        if flag {
            DispatchQueue.main.async { [weak self] in
                self?.playNext()
            }
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio decode error: \(error?.localizedDescription ?? "Unknown error")")
        DispatchQueue.main.async { [weak self] in
            self?.playNext()
        }
    }
}

import Foundation
import AVFoundation
import MediaPlayer
import Combine

final class AudioPlaybackEngine: NSObject, ObservableObject {
    static let shared = AudioPlaybackEngine()
    
    private var audioPlayer: AVAudioPlayer?
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
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupRemoteCommandCenter()
        setupAudioSession()
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
        guard let filePath = track.filePath else { return }
        let fileURL = URL(fileURLWithPath: filePath)
        
        do {
            audioPlayer?.stop()
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
    
    func play() {
        audioPlayer?.play()
        isPlaying = true
        startDisplayLink()
        updateNowPlayingInfo()
    }
    
    func pause() {
        audioPlayer?.pause()
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
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        stopDisplayLink()
        clearNowPlayingInfo()
    }
    
    func seek(to time: Double) {
        audioPlayer?.currentTime = time
        currentTime = time
        updateNowPlayingInfo()
    }
    
    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        audioPlayer?.volume = volume
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
    
    // MARK: - Display Link for Time Updates
    
    private func startDisplayLink() {
        stopDisplayLink()
        displayLink = CADisplayLink(target: self, selector: #selector(updatePlaybackTime))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 30)
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updatePlaybackTime() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
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
    }
    
    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
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

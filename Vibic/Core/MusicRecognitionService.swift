import Foundation
import AVFoundation
import ShazamKit

@MainActor
final class MusicRecognitionService: NSObject, ObservableObject, SHSessionDelegate {
    static let shared = MusicRecognitionService()
    
    @Published var isListening = false
    @Published var identifiedSong: IdentifiedSong?
    @Published var errorMessage: String?
    @Published var recordingProgress: Double = 0.0
    
    private var session: SHSession?
    private var audioEngine: AVAudioEngine?
    private var progressTask: Task<Void, Never>?
    private var recognitionContinuation: CheckedContinuation<IdentifiedSong?, Error>?
    
    struct IdentifiedSong: Equatable {
        let title: String
        let artist: String
        let artworkURL: URL?
        let appleMusicURL: URL?
        
        var searchQuery: String {
            "\(artist) - \(title)"
        }
        
        static func == (lhs: IdentifiedSong, rhs: IdentifiedSong) -> Bool {
            lhs.title == rhs.title && lhs.artist == rhs.artist
        }
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - Start Listening
    
    func startListening() async {
        // Prevent multiple simultaneous sessions
        guard !isListening else { return }
        
        // Reset state
        identifiedSong = nil
        errorMessage = nil
        recordingProgress = 0.0
        
        // Check microphone permission
        let permissionGranted = await requestMicrophonePermission()
        guard permissionGranted else {
            errorMessage = "Microphone access is required to identify songs"
            return
        }
        
        isListening = true
        print("[MusicRecognition] Starting ShazamKit recognition...")
        
        // Start progress animation
        startProgressAnimation()
        
        do {
            let song = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IdentifiedSong?, Error>) in
                self.recognitionContinuation = continuation
                self.startShazamSession()
            }
            
            if let song = song {
                print("[MusicRecognition] Match found: \(song.title) by \(song.artist)")
                identifiedSong = song
            } else {
                errorMessage = "Couldn't identify the song. Try again with clearer audio."
            }
        } catch {
            print("[MusicRecognition] Error: \(error)")
            if !Task.isCancelled {
                errorMessage = "Recognition failed: \(error.localizedDescription)"
            }
        }
        
        // Cleanup
        stopListeningInternal()
    }
    
    private func startShazamSession() {
        // Configure audio session FIRST (before accessing input node)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            recognitionContinuation?.resume(throwing: error)
            recognitionContinuation = nil
            return
        }
        
        // Create Shazam session
        session = SHSession()
        session?.delegate = self
        
        // Setup audio engine
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else {
            recognitionContinuation?.resume(throwing: NSError(domain: "MusicRecognition", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio engine"]))
            recognitionContinuation = nil
            return
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Verify we have a valid format
        guard recordingFormat.sampleRate > 0 else {
            recognitionContinuation?.resume(throwing: NSError(domain: "MusicRecognition", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid audio format. Sample rate: \(recordingFormat.sampleRate)"]))
            recognitionContinuation = nil
            return
        }
        
        print("[MusicRecognition] Recording format: \(recordingFormat.sampleRate) Hz, \(recordingFormat.channelCount) channels")
        
        // Install tap to capture audio
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: recordingFormat) { [weak self] buffer, time in
            self?.session?.matchStreamingBuffer(buffer, at: time)
        }
        
        // Start audio engine
        do {
            try audioEngine.start()
            print("[MusicRecognition] Audio engine started, listening...")
        } catch {
            recognitionContinuation?.resume(throwing: error)
            recognitionContinuation = nil
        }
    }
    
    // MARK: - SHSessionDelegate
    
    nonisolated func session(_ session: SHSession, didFind match: SHMatch) {
        Task { @MainActor in
            guard let firstItem = match.mediaItems.first else {
                self.recognitionContinuation?.resume(returning: nil)
                self.recognitionContinuation = nil
                return
            }
            
            let song = IdentifiedSong(
                title: firstItem.title ?? "Unknown Title",
                artist: firstItem.artist ?? "Unknown Artist",
                artworkURL: firstItem.artworkURL,
                appleMusicURL: firstItem.appleMusicURL
            )
            
            self.recognitionContinuation?.resume(returning: song)
            self.recognitionContinuation = nil
        }
    }
    
    nonisolated func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("[MusicRecognition] No match error: \(error)")
                self.recognitionContinuation?.resume(throwing: error)
            } else {
                print("[MusicRecognition] No match found")
                self.recognitionContinuation?.resume(returning: nil)
            }
            self.recognitionContinuation = nil
        }
    }
    
    // MARK: - Stop Listening
    
    func stopListening() {
        stopListeningInternal()
        
        // Cancel any pending continuation
        recognitionContinuation?.resume(returning: nil)
        recognitionContinuation = nil
    }
    
    private func stopListeningInternal() {
        stopProgressAnimation()
        
        // Stop audio engine
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        
        session = nil
        isListening = false
        recordingProgress = 0.0
        
        // Restore audio session for playback
        Task {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)
            } catch {
                print("[MusicRecognition] Failed to restore audio session: \(error)")
            }
        }
        
        print("[MusicRecognition] Stopped listening")
    }
    
    // MARK: - Progress Animation
    
    private func startProgressAnimation() {
        progressTask = Task {
            let maxDuration: Double = 15.0
            let updateInterval: Double = 0.1
            var elapsed: Double = 0.0
            
            while elapsed < maxDuration && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
                elapsed += updateInterval
                await MainActor.run {
                    recordingProgress = min(1.0 - exp(-elapsed / 5.0), 0.95)
                }
            }
        }
    }
    
    private func stopProgressAnimation() {
        progressTask?.cancel()
        progressTask = nil
    }
    
    // MARK: - Microphone Permission
    
    private func requestMicrophonePermission() async -> Bool {
        let status = AVAudioApplication.shared.recordPermission
        
        switch status {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }
}

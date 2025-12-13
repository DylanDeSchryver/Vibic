import Foundation
import AVFoundation
import CryptoKit

@MainActor
final class MusicRecognitionService: ObservableObject {
    static let shared = MusicRecognitionService()
    
    @Published var isListening = false
    @Published var identifiedSong: IdentifiedSong?
    @Published var errorMessage: String?
    @Published var recordingProgress: Double = 0.0
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTask: Task<Void, Never>?
    private var tempFileURL: URL?
    
    // ACRCloud credentials - stored in UserDefaults, configured via Settings
    private var acrHost: String {
        UserDefaults.standard.string(forKey: "acrCloudHost") ?? "identify-us-west-2.acrcloud.com"
    }
    private var acrAccessKey: String {
        UserDefaults.standard.string(forKey: "acrCloudAccessKey") ?? ""
    }
    private var acrAccessSecret: String {
        UserDefaults.standard.string(forKey: "acrCloudAccessSecret") ?? ""
    }
    
    var hasValidCredentials: Bool {
        !acrAccessKey.isEmpty && !acrAccessSecret.isEmpty
    }
    
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
    
    private init() {}
    
    // MARK: - Start Listening
    
    func startListening() async {
        // Reset state
        identifiedSong = nil
        errorMessage = nil
        recordingProgress = 0.0
        
        // Check ACRCloud credentials
        guard hasValidCredentials else {
            errorMessage = "ACRCloud API keys not configured. Add them in Settings."
            return
        }
        
        // Check microphone permission
        let permissionGranted = await requestMicrophonePermission()
        guard permissionGranted else {
            errorMessage = "Microphone access is required to identify songs"
            return
        }
        
        // Configure audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            errorMessage = "Failed to configure audio: \(error.localizedDescription)"
            return
        }
        
        // Create temp file for recording
        let tempDir = FileManager.default.temporaryDirectory
        tempFileURL = tempDir.appendingPathComponent("music_sample_\(UUID().uuidString).wav")
        
        guard let fileURL = tempFileURL else {
            errorMessage = "Failed to create temp file"
            return
        }
        
        // Recording settings - WAV format works best with ACRCloud
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 8000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.record()
            isListening = true
            print("[MusicRecognition] Started recording...")
            
            // Record for ~8 seconds with progress updates
            recordingTask = Task {
                let recordingDuration: Double = 8.0
                let updateInterval: Double = 0.1
                var elapsed: Double = 0.0
                
                while elapsed < recordingDuration && !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
                    elapsed += updateInterval
                    await MainActor.run {
                        recordingProgress = elapsed / recordingDuration
                    }
                }
                
                if !Task.isCancelled {
                    await finishRecordingAndIdentify()
                }
            }
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            isListening = false
        }
    }
    
    private func finishRecordingAndIdentify() async {
        audioRecorder?.stop()
        print("[MusicRecognition] Recording stopped, sending to ACRCloud...")
        
        guard let fileURL = tempFileURL else {
            errorMessage = "No recording file found"
            isListening = false
            return
        }
        
        do {
            // Read the audio file
            let audioData = try Data(contentsOf: fileURL)
            print("[MusicRecognition] Audio file size: \(audioData.count) bytes")
            
            // Send to ACRCloud
            let result = try await identifyWithACRCloud(audioData: audioData)
            
            if let song = result {
                print("[MusicRecognition] Match found: \(song.title) by \(song.artist)")
                identifiedSong = song
            } else {
                print("[MusicRecognition] No match found")
                errorMessage = "Couldn't identify the song. Try again with clearer audio."
            }
        } catch {
            print("[MusicRecognition] Error: \(error)")
            errorMessage = "Recognition failed: \(error.localizedDescription)"
        }
        
        // Cleanup
        cleanupTempFile()
        isListening = false
        recordingProgress = 0.0
        restoreAudioSession()
    }
    
    // MARK: - ACRCloud API
    
    private func identifyWithACRCloud(audioData: Data) async throws -> IdentifiedSong? {
        let httpMethod = "POST"
        let httpURI = "/v1/identify"
        let dataType = "audio"
        let signatureVersion = "1"
        let timestamp = String(Int(Date().timeIntervalSince1970))
        
        // Debug: Log credentials (first few chars only for security)
        let keyPreview = acrAccessKey.prefix(8)
        let secretPreview = acrAccessSecret.prefix(8)
        print("[MusicRecognition] Using host: \(acrHost)")
        print("[MusicRecognition] Access Key starts with: \(keyPreview)... (length: \(acrAccessKey.count))")
        print("[MusicRecognition] Access Secret starts with: \(secretPreview)... (length: \(acrAccessSecret.count))")
        
        // Create signature
        let stringToSign = "\(httpMethod)\n\(httpURI)\n\(acrAccessKey)\n\(dataType)\n\(signatureVersion)\n\(timestamp)"
        let signature = createHMACSHA1Signature(stringToSign: stringToSign, secret: acrAccessSecret)
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        
        // Add form fields
        let fields: [(String, String)] = [
            ("access_key", acrAccessKey),
            ("data_type", dataType),
            ("signature", signature),
            ("signature_version", signatureVersion),
            ("timestamp", timestamp),
            ("sample_bytes", String(audioData.count))
        ]
        
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"sample\"; filename=\"sample.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Create request
        let url = URL(string: "https://\(acrHost)/v1/identify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 15
        
        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ACRCloud", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        print("[MusicRecognition] ACRCloud response status: \(httpResponse.statusCode)")
        
        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        print("[MusicRecognition] ACRCloud response: \(String(data: data, encoding: .utf8) ?? "nil")")
        
        guard let status = json?["status"] as? [String: Any],
              let code = status["code"] as? Int else {
            throw NSError(domain: "ACRCloud", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        // Code 0 = success, 1001 = no result
        if code == 0, let metadata = json?["metadata"] as? [String: Any],
           let music = metadata["music"] as? [[String: Any]],
           let firstMatch = music.first {
            
            let title = firstMatch["title"] as? String ?? "Unknown Title"
            let artists = firstMatch["artists"] as? [[String: Any]]
            let artistName = artists?.first?["name"] as? String ?? "Unknown Artist"
            
            return IdentifiedSong(
                title: title,
                artist: artistName,
                artworkURL: nil,
                appleMusicURL: nil
            )
        }
        
        return nil
    }
    
    private func createHMACSHA1Signature(stringToSign: String, secret: String) -> String {
        let key = SymmetricKey(data: secret.data(using: .utf8)!)
        let signature = HMAC<Insecure.SHA1>.authenticationCode(for: stringToSign.data(using: .utf8)!, using: key)
        return Data(signature).base64EncodedString()
    }
    
    // MARK: - Stop Listening
    
    func stopListening() {
        recordingTask?.cancel()
        recordingTask = nil
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        cleanupTempFile()
        isListening = false
        recordingProgress = 0.0
        
        restoreAudioSession()
        print("[MusicRecognition] Stopped listening")
    }
    
    private func cleanupTempFile() {
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
            tempFileURL = nil
        }
    }
    
    private func restoreAudioSession() {
        Task {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)
            } catch {
                print("[MusicRecognition] Failed to restore audio session: \(error)")
            }
        }
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

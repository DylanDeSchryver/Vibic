import SwiftUI

@main
struct VibicApp: App {
    let coreDataManager = CoreDataManager.shared
    @StateObject private var libraryController = LibraryController.shared
    @StateObject private var playbackEngine = AudioPlaybackEngine.shared
    
    init() {
        configureAudioSession()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.viewContext)
                .environmentObject(libraryController)
                .environmentObject(playbackEngine)
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
}

import AVFoundation

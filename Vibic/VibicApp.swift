import SwiftUI

@main
struct VibicApp: App {
    let coreDataManager = CoreDataManager.shared
    @StateObject private var libraryController = LibraryController.shared
    @StateObject private var playbackEngine = AudioPlaybackEngine.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showSplash = true
    
    init() {
        configureAudioSession()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(\.managedObjectContext, coreDataManager.viewContext)
                    .environmentObject(libraryController)
                    .environmentObject(playbackEngine)
                    .tint(themeManager.accentColor)
                
                if showSplash {
                    SplashScreenView()
                        .transition(.opacity.animation(.easeOut(duration: 0.5)))
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
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

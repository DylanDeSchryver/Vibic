import SwiftUI

struct ContentView: View {
    @EnvironmentObject var libraryController: LibraryController
    @EnvironmentObject var playbackEngine: AudioPlaybackEngine
    @State private var selectedTab: Tab = .library
    @State private var showingPlayer = false
    
    enum Tab {
        case library
        case playlists
        case lyrics
        case files
        case settings
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "music.note.list")
                    }
                    .tag(Tab.library)
                
                PlaylistView()
                    .tabItem {
                        Label("Playlists", systemImage: "list.bullet")
                    }
                    .tag(Tab.playlists)
                
                LyricsView()
                    .tabItem {
                        Label("Lyrics", systemImage: "text.quote")
                    }
                    .tag(Tab.lyrics)
                
                FileBrowserView()
                    .tabItem {
                        Label("Files", systemImage: "folder")
                    }
                    .tag(Tab.files)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(Tab.settings)
            }
            
            if playbackEngine.currentTrack != nil {
                MiniPlayerView(showingPlayer: $showingPlayer)
                    .background(Color(.systemBackground))
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showingPlayer) {
            PlayerView()
        }
        .onOpenURL { url in
            libraryController.importFile(from: url)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
        .environmentObject(LibraryController.shared)
        .environmentObject(AudioPlaybackEngine.shared)
}

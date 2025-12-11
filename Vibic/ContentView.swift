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
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
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
            }
            .padding(.bottom, playbackEngine.currentTrack != nil ? 60 : 0)
            
            if playbackEngine.currentTrack != nil {
                VStack(spacing: 0) {
                    Spacer()
                    MiniPlayerView(showingPlayer: $showingPlayer)
                        .padding(.bottom, 49)
                }
            }
        }
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

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var libraryController: LibraryController
    @EnvironmentObject var playbackEngine: AudioPlaybackEngine
    @State private var selectedTab: Tab = .library
    @State private var showingPlayer = false
    @State private var showingSettings = false
    
    enum Tab {
        case library
        case search
        case playlists
        case lyrics
        case files
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                TabView(selection: $selectedTab) {
                    LibraryView()
                        .tabItem {
                            Label("Library", systemImage: "music.note.list")
                        }
                        .tag(Tab.library)
                    
                    StreamSearchView()
                        .tabItem {
                            Label("Search", systemImage: "magnifyingglass")
                        }
                        .tag(Tab.search)
                    
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
                
                if playbackEngine.currentTrack != nil {
                    MiniPlayerView(showingPlayer: $showingPlayer)
                        .background(Color(.systemBackground))
                }
            }
            
            // Floating Settings Button
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .padding(.top, 4)
            .padding(.leading, 16)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showingPlayer) {
            PlayerView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
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
